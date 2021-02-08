# ----------------------------------------------------------------------------
#
# Title:  Class Lists
#
# File - Protocol/Lists.pm
# Version - 1.0
#
# Name:
#
#       package Protocol::Lists
#
# Abstract:
#
#       This class manages types which are sequences of other elements.
# ------------------------------------------------------------------------
package Protocol::List;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $BYTES);

use Exporter;
use Log::Log4perl;
use Data::Dumper;

use lib "$ENV{'FTF'}/lib";
use Protocol::Utilities;
use Protocol::Type;
use Message;

$VERSION = 1;

@ISA = qw(Protocol::Type);

# list maxSize
use constant FIXED     => 0;
use constant BOUNDED   => 1;
use constant UNBOUNDED => 2;

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    # Call the parent initialization first
    $Self->Protocol::Type::_init(@_);

    die "Undefined element type name in list declaration" 
        unless (exists($Self->{'elementTypeName'}));
        
    my $eltTypeName = $Self->{'elementTypeName'};
    
    die "Unknown element type \"$eltTypeName\" in list declaration" unless (DefinedType($eltTypeName));    
    $Self->{'elementType'} = TypeFromName($eltTypeName);

    my %attr = @_;

    # Force structure attributs
    $Self->structure('list');

    if ( exists( $Self->{'numberOfElements'} ) ) {
        $Self->{'sizeMax'} = FIXED;
    }
}

# ------------------------------------------------------------------------
# method: numberOfElements
#
# for fix size lists: numberOfElements == maxNumberOfElements
# for bounded lists: numberOfElements is undefined and maxNumberOfElements is defined
# for unbounded lists: numberOfElements and maxNumberOfElements are undefined
# Return:
# the number of elements in this list type.
# ------------------------------------------------------------------------
sub numberOfElements {
    my $Self = shift;
    return $Self->{'numberOfElements'};
}

# ------------------------------------------------------------------------
# method: sizeMax
#
# Return:
# FIXED | BOUNDED | UNBOUNDED
# ------------------------------------------------------------------------
sub sizeMax {
    my $Self = shift;
    return $Self->{'sizeMax'};
}

# ------------------------------------------------------------------------
# method: maxNumberOfElements
#
# Return:
# the maximum number of elements in this list type.
# ------------------------------------------------------------------------
sub maxNumberOfElements {
    my $Self = shift;
    return $Self->{'maxNumberOfElements'};
}

# ------------------------------------------------------------------------
# method: encode
#
# Encode a list of values
#
# Parameters:
# $value - reference to a list of values
#
# Return: a binary buffer
# ------------------------------------------------------------------------
sub encode {
    my ( $Self, $value ) = @_;

    my $log = $Self->{Logger};
    my $ref = ref($value);
    die "Array reference expected to encode a list, got $ref"
      if ( $ref ne "ARRAY" );

    $log->info( "List.encode(" . join( ", ", @{$value} ) . ")" );

    # Check size of fix size list
    if ( exists( $Self->{'numberOfElements'} ) ) {
        my $nb = scalar( @{$value} );
        if ( $nb != $Self->{'numberOfElements'} ) {
            die
"List.encode incorrect number of list elements ($nb), expected=$Self->{'numberOfElements'}";
        }
    }

    # Check limit of bounded list
    if ( exists( $Self->{'maxNumberOfElements'} ) ) {
        my $nb = scalar( @{$value} );
        if ( $nb > $Self->{'maxNumberOfElements'} ) {
            die
"List.encode too many element $nb, for a list bounded to $Self->{'numberOfElements'}";
        }
    }

    my $buffer;
    if (exists($Self->{'numberTypeName'})) {
        $buffer .= Encode ($Self->{'numberTypeName'}, scalar(@{$value}));
    }
    
    foreach my $elt ( @{$value} ) {
        $buffer .= $Self->{'elementType'}->encode($elt);
    }
    return $buffer;
}

# ------------------------------------------------------------------------
# method: decode
#
# Decode a binary buffer and return a list
# is virtual and each type implementation will have to provide one.
# ------------------------------------------------------------------------
sub decode {
    my ( $Self, $bin ) = @_;

    my $log = $Self->{Logger};
    $log->trace($Self->{'Class'} . " decode(\"" . bin2hexa($bin) . ")\"");
    my $raw=$bin;

    my $msg = new Message(
        value  => [],
        errors => 0,
        type   => $Self->{'name'},
        size   => 0
    );

    # number of elements from the type
    my $nb = $Self->numberOfElements();

    # the number of elements is encoded in the message
    my $bin_nb;
    if (exists($Self->{'numberTypeName'})) {
        # read the number of element in the binary buffer
        my $number = Decode ($Self->{'numberTypeName'}, $bin);
        pop_message( \$bin, $number->size() );
        $bin_nb = $number->value();
        my $snb = defined($nb) ? $nb : "undef";
        $log->warn($Self->{'Class'} . "\{numberOfElement => $snb\}, value=$bin_nb");
        
        if ( defined($nb) ) {
            if ($nb != $bin_nb) {
                $msg->add_error("$nb elements expected in the list \"" .
                    $Self->{'name'} .
                    "\", found $bin_nb");
                $log->error($Self->{'Class'} . ' ' . $msg->error_description());
            }
        }
    }
    
    if ( defined($nb) ) {
        # fixed size list
        $log->warn($Self->{'Class'} . "\{numberOfElement => $nb\}");
        for ( my $i = 0 ; $i < $nb ; $i++ ) {
            my $elt = $Self->{'elementType'}->decode($bin);
            pop_message( \$bin, $elt->size() );
            $msg->{'value'}[$i] = $elt->value();
            $msg->{'size'} += $elt->size();

            if ( $elt->errors() ) {
                # some errors have been found while decoding the element
                # concate them with the list errors
                $msg->add_error( "\[$i\]: " . $elt->error_description(), $elt->errors() );
                $log->error($Self->{'Class'} . ' ' . $msg->error_description());
            }
        }
    }
    else {
        # unbounded list
        my $cnt = 0;
        while (1) {
            # when the buffer is empty
            unless (length($bin)) {
                $msg->{'number'} = $cnt;
                $log->info($Self->{'Class'} . " read $cnt elements"); 
                return $msg;
            }
            my $elt = $Self->{'elementType'}->decode($bin);
            pop_message( \$bin, $elt->size() );
            $msg->{'value'}[$cnt] = $elt->{'value'};

            if ( $elt->errors() ) {
                # some errors have been found while decoding the element
                # concate them with the list errors
                $msg->add_error("\[$cnt\]: " . $elt->error_description(), $elt->errors() );
                $log->error($Self->{'Class'} . ' ' . $msg->error_description());
            }
            $cnt++;
            if (defined($bin_nb)) {
                return $msg if ($cnt == $bin_nb);   # number of element read
                unless (length($bin)) {
                    $msg->add_error ("found only $cnt element in the list \"" . 
                    $Self->{'name'} . "\", expected=$bin_nb");
                    $log->error($Self->{'Class'} . ' ' . $msg->error_description());            
                }
            }
        }
    }
    $log->debug($Self->{'Class'} . " raw=" . bin2hexa (substr($raw, 0, $msg->size())));
    $log->info($Self->{'Class'} . " read $nb elements");
    $log->info($Self->{'Class'} . " value=" . $msg->dump()); 
    return $msg;
}

1;
