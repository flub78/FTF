# ----------------------------------------------------------------------------
# Title:  Class TLV_List
#
# File - Protocol/TLV_List.pm
# Version - 1.0
#
# Name:
#
#       package Protocol::TLV_List
#
# Abstract:
#
#       TLV lists are lists of TLV records. They are not exactly lists
#       because their elements can be from different type as long as
#       they are TLV records.
# ------------------------------------------------------------------------
package Protocol::TLV_List;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $BYTES);

use Exporter;
use Log::Log4perl;
use Data::Dumper;

use lib "$ENV{'FTF'}/lib";
use Protocol::Utilities;
use Protocol::List;
use Protocol::Type;
use Message;
use Carp;

$VERSION = 1;

@ISA = qw(Protocol::List);

use constant FALSE => 0;
use constant TRUE  => 1;
@EXPORT = qw(TRUE FALSE);

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
#
# Parameters:
# name - type name
# elements - list of TLV elements {name => ..., mandatory=> ..., multiple => ...}
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    # Call the parent initialization first
    $Self->Protocol::Type::_init(@_);

    my $class = $Self->{'Class'};
    croak $class . ": Undefined elements attribute in TLV list declaration"
      unless ( exists( $Self->{'elements'} ) );

    # take the descriptor from method parameter
    foreach my $fld ( @{ $Self->{'elements'} } ) {
        my $name = $fld->{'name'};

        # check that the field as a name attribute
        croak "missing field name" unless ( defined($name) );
        croak "unknown type \"$name\""
          unless ( DefinedType($name) );
        my $type = TypeFromName($name);
        
        croak "$name is not a TLV_Record" unless
           ($type->{'Class'} eq 'Protocol::TLV');

        my $tag_type = $type->tag_type();
        if (exists($Self->{'tag_type'})) {
            # check that they are all equal
            croak $Self->{'Class'} . ": $fld has a different tag type " . $tag_type .
               " than other fields"
            unless ($Self->{'tag_type'} eq $tag_type);
        } else {
            # save the tag size
            $Self->{'tag_type'} = $tag_type;
            $Self->{'tag_length'} = TypeFromName($tag_type)->size();
        }
        
        my $length_type = $type->length_type();
        if (exists($Self->{'length_type'})) {
            # check that they are all equal
            croak $Self->{'Class'} . ": $fld has a different length type " . $length_type .
               " than other fields"
            unless ($Self->{'length_type'} eq $length_type);
        } else {
            # save the length size
            $Self->{'length_type'} = $length_type;
            $Self->{'length_length'} = TypeFromName($length_type)->size();
        }
           
        my $tag = $type->tag();
         
        # add the new element
        push( @{ $Self->{'fields'} }, $name );
        $Self->{'elt_by_tag'}->{$tag} = $fld;
        $Self->{'elt_by_name'}->{$name} = $fld;
    }
    # print "New TLV list ", Dumper ($Self), "\n";
}

# ------------------------------------------------------------------------
# method: numberOfElements
#
# Return:
# the number of parameters in this TLV list type.
# ------------------------------------------------------------------------
sub numberOfElements {
    my $Self = shift;
    return scalar( @{ $Self->{'fields'} } );
}

# ------------------------------------------------------------------------
# method: encode
#
# Encode a list of values
#
# Example:
# (start code)
#     my $bin = $myList->encode ( {
#        COUNTER => 1,
#        SN => 2,
#        PASSWORD => "0123456789ABCDEF0123456789ABCDEF"
#    });
#
# (end)
# Parameters:
# $value - reference to a hash table
#
# Return: a binary buffer
# ------------------------------------------------------------------------
sub encode {
    my ( $Self, $value ) = @_;

    my $log = $Self->{Logger};
    my $ref = ref($value);
    croak "Hash reference expected to encode a TLV list, got $ref"
      if ( $ref ne "HASH" );

    $log->info( "TLV_List.encode(" . Dumper($value) . ")" );

    my $buffer;
    foreach my $fld ( @{ $Self->{'fields'} } ) {

        my $mandatory = $Self->{'elt_by_name'}->{$fld}->{'mandatory'};
        my $multiple = $Self->{'elt_by_name'}->{$fld}->{'multiple'};
        
        if ($mandatory) {
            # error when no value is provided
            croak "No value provided for encoding $fld" unless
            (exists ($value->{$fld}));
        } else {
            # skip when no value is provided
            next unless
            (exists ($value->{$fld}));
        }
        if ($multiple) {
            my $ref = ref($value->{$fld});
            croak "a list must be provided for multiple element \"$fld\"" unless
            ($ref eq "ARRAY");
            
            foreach my $val (@{$value->{$fld}}) {
                # print "Encoding $fld => $val\n";
                $buffer .= Encode( $fld, $val);                
            }            
        } else {
            # print "Encoding $fld => $value->{$fld}\n";
            $buffer .= Encode( $fld, $value->{$fld} );
        }
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

    # log routine call
    my $log = $Self->{Logger};
    $log->trace($Self->{'Class'} . " decode(\"" . bin2hexa($bin) . ")\"");
    if (defined($Self->{'fields'})) {
        $log->warn($Self->{'Class'} .  " fields=\[" . join (", ", @{$Self->{'fields'} }) . "\]");
    } 
    # prepare an empty message
    my $msg = new Message(
        value  => {},
        errors => 0,
        type   => $Self->{'name'},
        size   => 0
    );
    
    # check that there is at least enough data for tag and length
    my $tag_length = $Self->{'tag_length'};
    my $length_length = $Self->{'length_length'}; 
    if (length($bin) < ($tag_length + $length_length)) {
        $msg->add_error("Binary buffer too small for a TLV list");
        $log->error($Self->{'Class'} . ' ' . $msg->error_description());
        return $msg;
    }
    
    if ($tag_length . $length_length eq "") {
        # Case of empty list
        return $msg;
    }
    
    my $intType = new Protocol::Integer();
    while (length($bin) >= ($tag_length + $length_length)) {
        # extract tag
        $intType->size($tag_length);
        my $tag = $intType->decode($bin)->value();
    
        # extract length
        $intType->size($length_length);
        my $len = $intType->decode(substr ($bin, $tag_length, $length_length))->value();
    
        # type is
        my $type_name = $Self->{'elt_by_tag'}->{$tag}->{'name'};
        
        # decode elt
        my $elt_buf = pop_message (\$bin, $tag_length + $length_length + $len);
        
        unless (DefinedType($type_name)) {
            $msg->add_error("unknown type for tag=" . $tag);
            $log->error($Self->{'Class'} . ' ' . $msg->error_description());
            return $msg;
        }
        my $type = TypeFromName($type_name);
        
        # decode the element
        $log->warn($Self->{'Class'} ." decode element: tag=" . sprintf ("0x%X", $tag) . ", field=" . $type_name);
        my $elt = $type->decode ($elt_buf);
        
        # save the element value inside the message
        my $multiple = $Self->{'elt_by_tag'}->{$tag}->{'multiple'};
        if ($multiple) {
            # multiple
            if (exists($msg->{'value'}->{$elt->type()})) {
                # not the first one, push in the existing list
                push (@{$msg->{'value'}->{$elt->type()}}, $elt->value());            
            } else {
                # the first one, create the list
                $msg->{'value'}->{$elt->type()} = [ $elt->value() ];
            }  
        } else {
            # single element, add elt to message
            if (exists($msg->{'value'}->{$elt->type()})) {
                $msg->add_error("$type_name duplicated tag=$tag");
                $log->error($Self->{'Class'} . ' ' . $msg->error_description());                
            } else {
                $msg->{'value'}->{$elt->type()} = $elt->value();
            }
        }
        $msg->{'size'} += $elt->size();
        
        if ( $elt->errors() ) {
            # some errors have been found while decoding the element
            # concate them with the list errors
            $msg->add_error( "field \"" . $elt->type() . "\": " . $elt->error_description(),
                $elt->errors() );
            $log->error($Self->{'Class'} . ' ' . $msg->error_description());
        }
    }

    # Check the mandatory fields
    foreach my $fld ( @{ $Self->{'fields'} } ) {
        my $mandatory = $Self->{'elt_by_name'}->{$fld}->{'mandatory'};
        if ($mandatory) {
            $msg->add_error("missing mandatory field $fld")
            unless (exists($msg->{'value'}->{$fld}));
        }
    }
    
    $log->info($Self->{'Class'} . " value=" . $msg->dump());
    return $msg;
}

1;
