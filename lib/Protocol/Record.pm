# ----------------------------------------------------------------------------
#
# Title:  Class Record
#
# File - Protocol/Record.pm
# Version - 1.0
#
# Name:
#
#       package Protocol::Record
#
# Abstract:
#
#       Records are sequentail list of fields which are accessed
# by name. Fields can be of any type. To declare a new type you must
# provide a list of fields in the correct order. Fields descriptor
# contain a name, a type and optionally a value. When a value is
# provided, it is no more required during encoding, the value
# from the type is used. Type values can be overwrittent during encoding.
#
# Usage:
# (start code)
#    my $dateType = new Protocol::Record(
#        name => 'date',
#        field_descriptors => [
#            {name => 'day',   type => 'byte'},
#            {name => 'month', type => 'byte'},
#            {name => 'year',  type => 'unsigned16'}
#        ]
#    );
# (end)
# ------------------------------------------------------------------------
package Protocol::Record;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $BYTES);

use Exporter;
use Log::Log4perl;
use Data::Dumper;
use Carp;

use lib "$ENV{'FTF'}/lib";
use Protocol::Utilities;
use Protocol::Type;
use Message;

$VERSION = 1;

@ISA = qw(Protocol::Type);
@EXPORT = qw (declare_record);

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# 
# Parameters:
# name - type name
# field_descriptors - list of {name => ..., type => ...}
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    $Self->{'fields'} = [];

    # Call the parent initialization first
    $Self->Protocol::Type::_init(@_);

    my %attr = @_;

    # Force structure attributs
    $Self->structure('record');

    unless ( exists( $Self->{'field_descriptors'} ) ) {
        croak "field_descriptors attribute expected to declare a record";
    }

    if ( exists( $Self->{'parent'} ) ) {
        my $parent = TypeFromName( $Self->{'parent'} );

        # copy the list of field from the parent
        my @parent_fields = @{ $parent->{'fields'} };
        $Self->{'fields'} = \@parent_fields;

        # copy the field descriptors from the parent
        foreach my $pfld (@parent_fields) {
            my %fld_desc = %{ $parent->{'field'}->{$pfld} };
            $Self->{'field'}->{$pfld} = \%fld_desc;
        }
    }

    # take the descriptor from method parameter
    foreach my $fld ( @{$Self->{'field_descriptors'}} ) {
        my $name = $fld->{'name'};

        # check that the field as a name attribute
        croak "missing field name" unless ( defined($name) );

        if ( exists( $Self->{'field'}->{$name} ) ) {

            # field exist, it has been inherited from the parent
            # overwrite or merge with the child descriptor.
            my %fld_desc = %{$fld};
            foreach my $key ( keys(%fld_desc) ) {
                $Self->{'field'}->{$name}->{$key} = $fld_desc{$key};
            }
        }
        else {
            # type checks are done here because type can be inherited
            my $type = $fld->{'type'};    
            croak "missing type for field $name" unless ( defined($type) );
            croak "unknown type \"$type\" for field $name"
              unless ( DefinedType($type) );
            
            # add the new field
            push( @{ $Self->{'fields'} }, $name );
            my %fld_desc = %{$fld};
            $Self->{'field'}->{$name} = \%fld_desc;
        }
    }
}

# ------------------------------------------------------------------------
# method: numberOfFields
#
# Return:
# the number of fields in this record type.
# ------------------------------------------------------------------------
sub numberOfFields {
    my $Self = shift;
    return scalar( @{ $Self->{'fields'} } );
}

# ------------------------------------------------------------------------
# method: fields
#
# Return:
# the list of fields for the record.
# ------------------------------------------------------------------------
sub fields {
    my $Self = shift;
    return @{ $Self->{'fields'} };
}

# ------------------------------------------------------------------------
# method: encode
#
# Encode a list of values
#
# Return: a binary buffer
# ------------------------------------------------------------------------
sub encode {
    my ( $Self, $value ) = @_;

    my $log = $Self->{Logger};
    my $ref = ref($value);
    croak "Hash reference expected to encode a record, got $ref"
      if ( $ref ne "HASH" );

    $log->info( "Record.encode(" . Dumper($value) . ")" );

    # encode all the fields of the record
    my $buffer;
    my $encoded  = {};
    my $typename = $Self->{'name'};
    foreach my $fld ( @{ $Self->{'fields'} } ) {
        my $val;
        
        # check if the field must be skipped
        if ( exists( $Self->{'field'}->{$fld}->{'condition'} ) ) {
            my $cond = $Self->{'field'}->{$fld}->{'condition'};
            my $exist = eval $cond;
            unless ($exist) {
                croak "no value expected for \"$fld\" as \($cond\) is false" 
                    if (exists($value->{$fld}));
                next;
            }
        }
        
        # default value defined during type declaration ?
        if ( exists( $Self->{'field'}->{$fld}->{'default'} ) ) {
            $val = $Self->{'field'}->{$fld}->{'default'};
        }
        #  value defined during type declaration
        if ( exists( $Self->{'field'}->{$fld}->{'value'} ) ) {
            $val = $Self->{'field'}->{$fld}->{'value'};           
        }
        # value passed as parameter    
        if ( exists( $value->{$fld} ) ) {
            $val = $value->{$fld};
            # check that the value is correct
            if ( exists( $Self->{'field'}->{$fld}->{'value'} ) ) {
                croak "$fld value must be " . $Self->{'field'}->{$fld}->{'value'}
                    unless ($val == $Self->{'field'}->{$fld}->{'value'});
            }
        }
        
        # check if a value has been found
        croak "no value provided for field \"$fld\" while encoding a \"$typename\""
            unless (defined($val));
            
        # evaluate the value for dynamic support
        $val = eval {$val};
        
        my $type = $Self->{'field'}->{$fld}->{'type'};
        $buffer .= Encode( $type, $val );
        $encoded->{$fld} = 1;
    }

    # check that no extra values have been provided
    foreach my $vfld ( keys( %{$value} ) ) {
        croak "unexpected value field \"$vfld\" while encoding a \"$typename\""
          unless ( exists( $encoded->{$vfld} ) );
    }
    return $buffer;
}

# ------------------------------------------------------------------------
# method: decode
#
# Decode a binary buffer and return a record message
# ------------------------------------------------------------------------
sub decode {
    my ( $Self, $bin ) = @_;

    my $log = $Self->{Logger};
    $log->trace($Self->{'Class'} . " decode(\"" . bin2hexa($bin) . ")\"");
    $log->warn($Self->{'Class'} .  " fields=\[" . join (", ", @{$Self->{'fields'} }) . "\]");
    my $raw=$bin;  
    my $msg = new Message(
        value  => {},
        errors => 0,
        type   => $Self->{'name'},
        size   => 0
    );

    my $value = {};
    foreach my $fld ( @{ $Self->{'fields'} } ) {
        # check if the field must be skipped
        if ( exists( $Self->{'field'}->{$fld}->{'condition'} ) ) {
            my $cond = $Self->{'field'}->{$fld}->{'condition'};
            my $exist = eval $cond;
            next unless ($exist);
        }        
        
        my $type = $Self->{'field'}->{$fld}->{'type'};
        my $elt  = Decode( $type, $bin );

        # print "$fld = " . Dumper ($elt) . "\n";

        pop_message( \$bin, $elt->size() );
        $value->{$fld} = $elt->value();
        $msg->{'size'} += $elt->size();
        
        my $expected_value;
        #  value defined during type declaration
        if ( exists( $Self->{'field'}->{$fld}->{'value'} ) ) {
            $expected_value = $Self->{'field'}->{$fld}->{'value'};           
            croak "incorrect value for field $fld" unless ($value->{$fld} eq $expected_value);
        }        

        if ( $elt->errors() ) {

            # some errors have been found while decoding the element
            # concate them with the list errors
            $msg->add_error( "field \"$fld\": " . $elt->error_description(),
                $elt->errors() );
            $log->error($Self->{'Class'} . ' ' . $msg->error_description());
        }
    }
    $msg->{'value'} = $value;
    $log->debug($Self->{'Class'} . " raw=" . bin2hexa (substr($raw, 0, $msg->size())));
    $log->info($Self->{'Class'} . " value=" . $msg->dump());
    return $msg;
}

# ------------------------------------------------------------------------
# method: declare_record
#
# shortcut for
# (start code)
#    declare Protocol::Record(
#        name              => $name,
#        field_descriptors => $field_descriptors
#    );
# (end code)
# ------------------------------------------------------------------------
sub declare_record {
    my ($name, $field_descriptors) = @_;

    declare Protocol::Record(
        name              => $name,
        field_descriptors => $field_descriptors
    );
}

1;
