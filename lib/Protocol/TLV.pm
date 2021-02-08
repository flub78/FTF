# ----------------------------------------------------------------------------
#
# Title:  Class TLV
#
# File - Protocol/TLV.pm
# Version - 1.0
#
# Name:
#
#       package Protocol::TLV
#
# Abstract:
#
#       A TLV encoding consists of three fields (a tuple): Type, Length and Value.
#       TLV is a formatting scheme that adds a tag to each transmitted parameter
#       containing the parameter type and the length of the encoded parameter
#       (the value). The type implicitly contains the encoding rules.
#
#       A new attribute, 'no_tag' has been added to support LV types.
# 
# Usage:
# (start code)
#    declare Protocol::TLV(
#        name => 'MOP',
#        tag => 0x01,
#        tag_type => 'byte',
#        length_type => 'unsigned32',
#        value_type => 'unsigned16',
#    );
# or
#    declare Protocol::TLV(
#        name => 'MOP',
#        no_tag => 1,
#        length_type => 'unsigned32',
#        value_type => 'unsigned16',
#    );
# (end)
# ------------------------------------------------------------------------
package Protocol::TLV;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $BYTES);

use Exporter;
use Log::Log4perl;
use Data::Dumper;

use lib "$ENV{'FTF'}/lib";
use Protocol::Utilities;
use Protocol::Type;
use Message;
use Carp;

$VERSION = 1;

@ISA    = qw(Protocol::Type);
@EXPORT = qw (declare_tlv);

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
#
# Parameters:
# name - type name
# tag - tag value
# tag_type - type used for the tag field
# length_type - type used for the length
# value_type - type of the value field
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    # Call the parent initialization first
    $Self->Protocol::Type::_init(@_);

    # Force structure attributs
    $Self->structure('scalar');
    my $class = $Self->{'Class'};
    my $type;

    unless ( $Self->{'no_tag'} ) {
        croak $class . ": tag attribute is required for TLV definition"
          unless ( exists( $Self->{'tag'} ) );
        croak $class . ": tag_type attribute is required for TLV definition"
          unless ( exists( $Self->{'tag_type'} ) );
        $type = TypeFromName( $Self->{'tag_type'} );
        croak $class . "tag_type must be an integer type"
          unless ( $type->{'Class'} eq 'Protocol::Integer' );
        $Self->{'tag_ref'} = $type;
    }

    croak $class . ": length_type attribute is required for TLV definition"
      unless ( exists( $Self->{'length_type'} ) );
    croak $class . ": value_type attribute is required for TLV definition"
      unless ( exists( $Self->{'value_type'} ) );

    $type = TypeFromName( $Self->{'length_type'} );
    croak $class . "length_type must be an integer type"
      unless ( $type->{'Class'} eq 'Protocol::Integer' );
    $Self->{'length_ref'} = $type;

    if ( exists( $Self->{'value_type'} ) ) {
        if ( defined( $Self->{'value_type'} ) ) {
            if ( $Self->{'value_type'} ne "" ) {
                $Self->{'value_ref'} = TypeFromName( $Self->{'value_type'} );
            }
        }
    }
}

# ------------------------------------------------------------------------
# method: encode
#
# Encode a list of fields
#
# Parameters:
# $value - a value compatible with the value part of a TLV. Supported types depned on the 'value_type' attribute.
# Return: a binary buffer
# ------------------------------------------------------------------------
sub encode {
    my ( $Self, $value ) = @_;

    my $log      = $Self->{Logger};
    my $typename = $Self->{'name'};

    # encode the tag
    my $tag_field = "";
    unless ( $Self->{'no_tag'} ) {
        $tag_field = $Self->{'tag_ref'}->encode( $Self->{'tag'} );
    }

    # encode the VALUE field
    my $value_field = $Self->{'value_ref'}->encode($value);

    # encode the length
    my $length_field = $Self->{'length_ref'}->encode( length($value_field) );

    return $tag_field . $length_field . $value_field;
}

# ------------------------------------------------------------------------
# method: decode
#
# Decode a binary buffer and return a record message. The main difference
# with regular record decode, is that fields name are predefined and
# the buffer is truncated according LENGTH
# ------------------------------------------------------------------------
sub decode {
    my ( $Self, $bin ) = @_;

    my $raw = $bin;
    my $log = $Self->{Logger};
    $log->trace( $Self->{'Class'} . " decode(\"" . bin2hexa($bin) . ")\"" );
    $log->warn( $Self->{'Class'}
          . " tag_type="
          . $Self->{'tag_type'}
          . ", length_type="
          . $Self->{'length_type'} );
    my $msg = new Message(
        value  => {},
        errors => 0,
        type   => $Self->{'name'},
        size   => 0
    );

    # tag
    my $tag = "";
    unless ( $Self->{'no_tag'} ) {
        my $tag_msg = $Self->{'tag_ref'}->decode($bin);
        $tag = $tag_msg->value();
        $msg->{'tag'} = $tag;
        croak $Self->{'Class'} . ": incorrect tag=$tag"
          unless ( $Self->{'tag'} == $tag );
        pop_message( \$bin, $tag_msg->size() );
    }

    # length
    my $len_msg = $Self->{'length_ref'}->decode($bin);
    my $len     = $len_msg->value();
    $msg->{'length'} = $len;
    pop_message( \$bin, $len_msg->size() );

    # check that there is enough data
    if ( length($bin) < $len ) {
        $msg->add_error( $Self->{'Class'}
              . ": not enough data, size="
              . length($bin)
              . ", encoded length="
              . $len );
        $log->error( $Self->{'Class'} . ' ' . $msg->error_description() );
        return $msg;
    }
    $bin = substr( $bin, 0, $len );

    # check that data length is compatible with the declared type
    if ( exists( $Self->{'value_ref'} ) ) {
        my $type_size = $Self->{'value_ref'}->size();
        if ( defined($type_size) ) {
            if ( $len != $type_size ) {
                $msg->add_error( $Self->{'Class'}
                      . ": incorrect length="
                      . $len
                      . ", for type "
                      . $Self->{'value_ref'}->name()
                      . ", expected="
                      . $type_size );
                $log->error(
                    $Self->{'Class'} . ' ' . $msg->error_description() );
                return $msg;
            }
        }

        $log->warn( $Self->{'Class'}
              . " tag=$tag, length=$len, value type="
              . $Self->{'value_ref'}->name() );

        # value
        my $elt = $Self->{'value_ref'}->decode($bin);
        $msg->{'value'} = $elt->value();
        $msg->{'size'} = $Self->{'length_ref'}->size() +
          $elt->size();
        unless ( $Self->{'no_tag'} ) {
            $msg->{'size'} += $Self->{'tag_ref'}->size();
        }

        if ( $elt->errors() ) {

            # some errors have been found while decoding the element
            # concate them with the list errors
            $msg->add_error( "value: " . $elt->error_description(),
                $elt->errors() );
        }
    }
    else {
        $msg->{'value'} = undef;
        $msg->{'size'} =  $Self->{'length_ref'}->size();
        unless ( $Self->{'no_tag'} ) {
            $msg->{'size'} += $Self->{'tag_ref'}->size();
        }
    }
    $log->debug( $Self->{'Class'} . " raw="
          . bin2hexa( substr( $raw, 0, $msg->size() ) ) );
    $log->info( $Self->{'Class'} . " value=" . $msg->dump() );

    return $msg;
}

# ------------------------------------------------------------------------
# method: decode_tag
#
# Read anything required to extract the type tag of a buffer.
# This method is used by TLV_Alternative to find out
# the type of the message
# ------------------------------------------------------------------------
sub decode_tag {
    my ( $Self, $bin ) = @_;

    # tag
    my $tag_msg = $Self->{'tag_ref'}->decode($bin);
    return $tag_msg->value();
}

# ------------------------------------------------------------------------
# method: tag
#
# Return: the tag value of the TLV
# ------------------------------------------------------------------------
sub tag {
    my ($Self) = @_;

    return $Self->{'tag'};
}

# ------------------------------------------------------------------------
# method: tag_type
#
# Return: the tag type of the TLV
# ------------------------------------------------------------------------
sub tag_type {
    my ($Self) = @_;
    return $Self->{'tag_type'};
}

# ------------------------------------------------------------------------
# method: length_type
#
# Return: the length type of the TLV
# ------------------------------------------------------------------------
sub length_type {
    my ($Self) = @_;

    return $Self->{'length_type'};
}

# ------------------------------------------------------------------------
# method: value_type
#
# Return: the value type of the TLV
# ------------------------------------------------------------------------
sub value_type {
    my ($Self) = @_;

    return $Self->{'value_type'};
}

# ------------------------------------------------------------------------
# method: declare_tlv
#
# shortcut for
# (start code)
#    declare Protocol::TLV(
#        name => $name,
#        tag => $tag,
#        tag_type => $tag_type,
#        length_type => $length_type,
#        value_type => $value_type,
#    );
# (end code)
# ------------------------------------------------------------------------
sub declare_tlv {
    my ( $name, $tag, $tag_type, $length_type, $value_type ) = @_;

    declare Protocol::TLV(
        name        => $name,
        tag         => $tag,
        tag_type    => $tag_type,
        length_type => $length_type,
        value_type  => $value_type,
    );
}

1;
