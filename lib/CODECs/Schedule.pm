# ----------------------------------------------------------------------------
#
# Title: Class CODECs::Schedule
#
# File - CODECs::Schedule.pm
#
# Name:
#
#    package CODECs::Schedule
#
# Abstract:
#
# This is an example of CODEC implementation using the Protocol module
# support. This protocol Events several kinds of TLV messages;
#    - Teachers
#    - Rooms
#    - Classes which have a start and end time, a tacher and a room
#    - schedules which are lists of classes
#    - ACK which is the acknowledge message to the above ones.
#
# This protocol has not been designed to be useful in any way, but to demonstrate
# the services provided by the encoding method.
# ----------------------------------------------------------------------------
package CODECs::Schedule;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use CODECs;
use CODECs::Support;

use Protocol::Type;
use Protocol::Record;
use Protocol::List;
use Protocol::TLV;
use Protocol::TLV_List;
use Protocol::TLV_Alternative;
use Protocol::TLV_Message;

$VERSION = 1;
@ISA     = qw(CODECs);

##################################
# Section: Protocol definition
##################################

# Command tags
my $msg_tags = {
    ACK       => 0,
    TEACHER   => 0x10,
    ROOM      => 0x11,
    CLASSE    => 0x20,
    SCHEDULE  => 0x21};

# parameters tags
my $param_tags = {
    ID                    => 0x00,    
    NAME                  => 0x01,
    SUBJECT               => 0x02,
    COMMENT               => 0x03,
    ERROR                 => 0x04,
    DESCRIPTION           => 0x05,
    CLASS_LIST            => 0x55AA
};

# Message parameters internal types
declare_record ('TIME', [
    {name => 'HOUR',   type => 'byte'},
    {name => 'MINUTE', type => 'byte'}
]);

# ------------------------------------------------------------------
declare_record ('CLASS', [
    {name => 'DAY',        type => 'byte'},
    {name => 'START_TIME', type => 'TIME'},
    {name => 'END_TIME',   type => 'TIME'},
    {name => 'TEACHER',    type => 'unsigned32'},
    {name => 'ROOM',       type => 'unsigned32'},
]);

declare Protocol::List(
    'name'            => 'CLASS_LIST_VALUE',
    'numberTypeName'  => 'unsigned32',
    'elementTypeName' => 'CLASS'
);

# ------------------------------------------------------------------
# Messages parameters
#                 name         | tag type    | length type | value type
declare_parameter('ID'         , 'unsigned16', 'unsigned16', 'unsigned32');
declare_parameter('NAME'       , 'unsigned16', 'unsigned16', 'string');
declare_parameter('SUBJECT'    , 'unsigned16', 'unsigned16', 'string');
declare_parameter('COMMENT'    , 'unsigned16', 'unsigned16', 'string');
declare_parameter('ERROR'      , 'unsigned16', 'unsigned16', 'unsigned32');
declare_parameter('DESCRIPTION', 'unsigned16', 'unsigned16', 'string');
declare_parameter('CLASS_LIST' , 'unsigned16', 'unsigned16', 'CLASS_LIST_VALUE');

# Declaration of messages
declare_message ('ACK', [
    {name => 'ERROR',             mandatory => TRUE,  multiple => FALSE},
    {name => 'DESCRIPTION',       mandatory => FALSE, multiple => FALSE},
]);

declare_message('TEACHER', [
    {name => 'ID',                mandatory => TRUE,  multiple => FALSE},
    {name => 'NAME',              mandatory => TRUE,  multiple => FALSE},
    {name => 'SUBJECT',           mandatory => TRUE,  multiple => TRUE}
]);

declare_message('ROOM', [
    {name => 'ID',                mandatory => TRUE,  multiple => FALSE},
    {name => 'NAME',              mandatory => FALSE, multiple => FALSE},
]);

declare_message('SCHEDULE', [
    {name => 'ID',                mandatory => TRUE,  multiple => FALSE},
    {name => 'COMMENT',           mandatory => FALSE,  multiple => FALSE},
    {name => 'CLASS_LIST',        mandatory => TRUE,  multiple => FALSE},
]);

# It is possible to receive any of the defined messages
declare Protocol::TLV_Alternative (
    name     => 'SCHOOL',
    choices  => ['ACK', 'TEACHER', 'ROOM', 'SCHEDULE']);

# ============================================================================

##################################
# Section: CODECs Support
##################################

# ----------------------------------------------------------------------------
# method: message_length
#
# This method analyses a buffer and return the length of the first
# applicative message or -1 when the buffer does not contain any full message.
#
#    Parameters:
#       $buffer - binary buffer to analyze
# ----------------------------------------------------------------------------
sub message_length {
    my ( $Self, $buffer ) = @_;

    $Self->{'Logger'}->info("Schedule::message_length");

    # not enough space for tag and length
    return -1 if ( length($buffer) < 4 );

    # read tag and length
    my ( $tag, $len ) = unpack( "n n", $buffer );
    return -1 if ( length($buffer) < $len + 4 );

    return $len + 4;
}

# ----------------------------------------------------------------------------
# method: decode
#
# decode a binary message and return a structured message. The buffer is
# supposed to have the correct length.
#
# Parameters:
#     $bin - binary buffer truncated at a full application message
#
# Returns: a hash reference.
# ----------------------------------------------------------------------------
sub decode {
    my ( $Self, $bin ) = @_;

    $Self->{Logger}->info( "Schedule::decode (" . bin2hexa($bin) . ")" );
    return Decode('ECS_KM', $bin);
}

# ----------------------------------------------------------------------------
# method: encode
#
# encode a structured message and return a binary buffer, or die when the supplied
# values does not allow encoding.
#
# Parameters:
#     $msg - structured message to encode.
# ----------------------------------------------------------------------------
sub encode {
    my ( $Self, $msg ) = @_;
    
    $Self->{Logger}->info( "Schedule::encode, " . $msg->{'type'} );
    return Encode($msg->type(), $msg->value());
}

# ============================================================================

##############################################
# Section: Routines to improve the readibility
##############################################

# ----------------------------------------------------------------------------
# routine: declare_parameter
#
# Declare a TLV parameter using the $param_tags hash to associate tags and
# tag names.
#
# Parameters:
# $name - parameter name
# $tag_type -
# $length_type -
# $value_type -   
# ----------------------------------------------------------------------------
sub declare_parameter {
    my ($name, $tag_type, $length_type, $value_type) = @_;
    
    declare_tlv($name, $param_tags->{$name}, $tag_type, $length_type, $value_type); 
}

# ----------------------------------------------------------------------------
# routine: declare_message
#
# Declare a TLV message using the $msg_tags hass to associate tags and
# tag names.
#
# Parameters:
# $name - message type name
# $field_descriptors - TLV parameters    
# ----------------------------------------------------------------------------
sub declare_message {
    my ($name, $field_descriptors) = @_;
    
    declare Protocol::TLV_Message(
        name => $name,
        tag => $msg_tags->{$name},
        tag_type => 'unsigned16',
        length_type => 'unsigned16',
        elements => $field_descriptors
    );
}

1;
