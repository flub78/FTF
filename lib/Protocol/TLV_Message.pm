# ----------------------------------------------------------------------------
# Title:  Class TLV_Message
#
# File - Protocol/TLV_Message.pm
# Version - 1.0
#
# Name:
#
#       package Protocol::TLV_Message
#
# Abstract:
#
#       TLV_Message are combinaition of a header record and
#       a TLV list encapsulated into a TLV.
#       For encoding you must supply a list of values like to
#       encode a record, the routine will dispatch fields to 
#       encode in the header and fields to encode as TLV parameters.
#
#       The decode method returns a hash of values containing both 
#       fields from the header and fields from the TLV list. 
#
#       A new attribute 'no_tag' as been added to support TLV messages
#       without tags.
#
# Usage:
# (start code)
#    my $tlvm = new Protocol::TLV_Message(
#        name => 'msg',
#        field_descriptors => [
#            {name => 'protocol',   type => 'byte'},
#            {name => 'version', type => 'unsigned32'}
#        ],
#        tag => 0x35,
#        tag_type => 'byte',
#        length_type => 'unsigned32',
#        elements => [
#           {name => 'COUNTER', mandatory => TRUE,  multiple => FALSE},
#           {name => 'SN', mandatory => TRUE,  multiple => FALSE},
#           {name => 'TR_NUMBER', mandatory => FALSE, multiple => TRUE}
#       ]
#    );
# (end)
#
# ------------------------------------------------------------------------
package Protocol::TLV_Message;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $BYTES);

use Exporter;
use Log::Log4perl;
use Data::Dumper;

use lib "$ENV{'FTF'}/lib";
use Protocol::Utilities;
use Protocol::List;
use Protocol::Type;
use Protocol::Record;
use Protocol::TLV;
use Protocol::TLV_List;
use Message;

$VERSION = 1;

@ISA = qw(Protocol::Type);

# Seams to be a redundant definition
# use constant FALSE => 0;
# use constant TRUE  => 1;
# @EXPORT = qw(TRUE FALSE);

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
#
# Parameters:
# name              - type name
# field_descriptors - list of {name => ..., type => ...}
# tag               - tag value
# tag_type          - type used for the tag field
# length_type       - type used for the length
# elements          - list of TLV elements {name => ..., mandatory=> ..., multiple => ...}
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    # Call the parent initialization first
    $Self->Protocol::Type::_init(@_);

    my $class = $Self->{'Class'};
    die $class . ": anonymous TLV_Message not yet supported"
        unless (exists($Self->{'name'}));
    unless ($Self->{'no_tag'}) {
        die $class . ": tag attribute is required for TLV_Message definition" unless (exists($Self->{'tag'}));
        die $class . ": tag_type attribute is required for TLV_Message definition" unless (exists($Self->{'tag_type'}));
    } else {
        $Self->{'tag'} = undef;
        $Self->{'tag_type'} = undef;
    }
    die $class . ": length_type attribute is required for TLV_Message definition" unless (exists($Self->{'length_type'}));
    die $class . ": elements attribute is required for TLV_Message declaration"
      unless ( exists( $Self->{'elements'} ) );
    
    $Self->{'header'} = new Protocol::Record(
        name              => $Self->{'name'} . ".header",
        field_descriptors => $Self->{'field_descriptors'});
        
    $Self->{'parameters'} = new Protocol::TLV_List (
        name     => $Self->{'name'} . ".parameters",
        elements => $Self->{'elements'});

    $Self->{'tlv'} = new Protocol::TLV(
        name        => $Self->{'name'} . ".tlv",
        no_tag      => $Self->{'no_tag'},
        tag         => $Self->{'tag'},
        tag_type    => $Self->{'tag_type'},
        length_type => $Self->{'length_type'},
        value_type  => $Self->{'name'} . ".parameters",
    );

    # print "New TLV list ", Dumper ($Self), "\n";
}

# ------------------------------------------------------------------------
# method: numberOfFields
#
# Return:
# the number of positional fields in this TLV Message type.
# ------------------------------------------------------------------------
sub numberOfFields {
    my $Self = shift;
    return $Self->{'header'}->numberOfFields();
}

# ------------------------------------------------------------------------
# method: fields
#
# Return:
# the list of fields for the TLV message.
# ------------------------------------------------------------------------
sub fields {
    my $Self = shift;
    return $Self->{'header'}->fields();
}

# ------------------------------------------------------------------------
# method: numberOfElements
#
# Return:
# the number of parameterss in this TLV Message type.
# ------------------------------------------------------------------------
sub numberOfElements {
    my $Self = shift;
    return $Self->{'parameters'}->numberOfElements();
}

# ------------------------------------------------------------------------
# method: tag
#
# Return: the tag value of the TLV
# ------------------------------------------------------------------------
sub tag {
    my ( $Self) = @_;
    
    return $Self->{'tag'};
}

# ------------------------------------------------------------------------
# method: tag_type
#
# Return: the tag type of the TLV
# ------------------------------------------------------------------------
sub tag_type {
    my ( $Self) = @_;
    return $Self->{'tag_type'};
}


# ------------------------------------------------------------------------
# method: length_type
#
# Return: the length type of the TLV
# ------------------------------------------------------------------------
sub length_type {
    my ( $Self) = @_;
    
    return $Self->{'length_type'};
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
    die "Hash reference expected to encode a TLV Message, got $ref"
      if ( $ref ne "HASH" );

    $log->info( "TLV_Message.encode(" . Dumper($value) . ")" );
    # dispatch the parameter among the header and TLV parameter
    my $param_list = \%{$value};
    my $header_list = {};
    foreach my $key ($Self->fields()) {
        # if found a value for a header field
        if (exists($value->{$key})) {
            $header_list->{$key} = $value->{$key};
            delete ($value->{$key});
        }
    }

    my $buffer = $Self->{'header'}->encode($header_list);
    $buffer .= $Self->{'tlv'}->encode($param_list);
    
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
    $log->warn($Self->{'Class'} .  " fields=\[" . join (", ", $Self->fields() ) . "\]");
  
    my $msg = $Self->{'header'}->decode($bin);
    pop_message( \$bin, $msg->size() );
    my $msg_param = $Self->{'tlv'}->decode($bin);
    
    $msg->type($Self->{'name'});
    if ($msg_param->errors()) {
        $msg->add_error($msg_param->error_description(), $msg_param->errors());
    }
    
    # print "parameters = " . Dumper($msg_param) . "\n";
    foreach my $key (keys(%{$msg_param->{'value'}})) {
        $msg->{'value'}->{$key} = $msg_param->{'value'}->{$key};
    }
    $msg->{'size'} += $msg_param->size();
    $msg->{'length'} = $msg_param->length();
    $msg->{'tag'} = $msg_param->tag();
    $log->info($Self->{'Class'} . " value=" . $msg->dump());
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

    my $msg = $Self->{'header'}->decode($bin);
    pop_message( \$bin, $msg->size() );

    # tag
    my $tag = $Self->{'tlv'}->decode_tag($bin);
    return $tag;
}

1;
