# ----------------------------------------------------------------------------
#
# Title: Class CODECs
#
# File - CODECs.pm
# Author - frederic
#
# Name:
#
#    package CODECs
#
# Abstract:
#
# This class is the root class for all CODECs. CODECs are classes which support
# encoding and decoding of binary messages according to a specific protocol. All codecs
# have encode and decode methods to translate back and forth binary buffers
# into structured list of values. The structure lists of values are managed by the
# <Class Message>.
#
# In the first version I have also provided support to display these structured list of
# value specificly to each codec. In fact it is possible to have generic routines
# to build a message from a string and to display them. 
#
# CODEC contents:
# message_length - to recognize the boundaries of an application message.
# decode - to translate a binary buffer into a structured list of values 
# encode - to translate a structured list of values into a binary buffer
#
# This root class is abstract and should not be used directly.
# It provides a standardized interface to all the CODECs supported in
# the Framework and allow the classes from Events and Network to use
# a CODEC without knowing its exact properties and purpose.
#
# Section: Error Management
#
# Error management is a little different for encode and decode routines.
#
# encode - Normally when you encode a message you are supposed to provide
#          all the required information. So impossibility to generate
#          a correct message from the provided information are treated
#          by exception. In case of error, an exception with a detailled
#          description is raised.
#
# decode - In this case you are not responsible of the fact that the binary
#          buffer may not have been correctly formated. So the errors and
#          error_description attribute of the message are set. The user
#          must checks this information before to use the received message.
#          As far as possible, partial content will be put into the message.
#          The idea is that you can find useful information in the first
#          part of a message before to detect the error. In this case this
#          information is returned, it can help to construct better
#          error messages. For example, the field XXX is erroneous in the message
#          identified by the field YYY.
#
# Section: Usage
#
# encode:
#     Here is an example of message creation.
# 
#     (see encode.png)
#
# decode:
#
#     How to decode a message and access to its fields.
#     (see decode.png)
#
# dump:
#
#     Result of the dump method.
#
#     (see dump.png)
#
# Design note:
#
#    The two main principles for CODEC implementation are;
#
#    - Values to encode and layouts must be clearly separated.
#
#    - Encoding and decoding of containers or structured messages must
#    only relies on the container attributes and on the CODEC for sub-element.
#    For exemple to encode a list of elements you just have to know how
#    to encode a list and an element. You do not care to know if the element is 
#    a scalar or record or anything else.
#
#    I have use singleton for codecs because they do not contain any context, so
#    I do not need multiple instances. Note that the mechanism for dynamism is
#    not really clean either. I build dynamically a command to get the CODEC instance
#    and then evaluate it. 
#    
#    The second principle requires that encode and decode methods must have
#    exactly the same profile whatever the type of message they handle. However I do
#    not want to write a class to encode integer on 16 bits and integers on 32 bits,
#    it implies some kind of parameters that must be passed to the CODEC. So we want to
#    encode values according to a layout or format. It raises the question:
#    do we need to access codec objects, or is it better to have encode and decode library
#    routines able to recognize and handle format.
#  
# TODO Changes parameters of encode_tlv_parameters
#
# ----------------------------------------------------------------------------
package CODECs;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Log::Log4perl;
use Class::Singleton;
use Message;
use Data::Dumper;
use CODECs::Support;

$VERSION = 1;

@ISA = qw(Class::Singleton);


#################################
# Section: Abstract CODECs class
#################################

# abstract class root of all CODECs

# ------------------------------------------------------------------------
# method: new
#
# Returns a new initialised object for the class.
# ------------------------------------------------------------------------
sub _new_instance {
	my $Class = shift;
	my $Self  = {};

	bless( $Self, $Class );

	$Self->{Logger} = Log::Log4perl::get_logger($Class);
	$Self->{Logger}->debug("Creating instance of $Class");
	$Self->_init(@_);

	return $Self;
}

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
	my $Self = shift;

	my %attr = @_;

	# Takes the constructor parameters as object attributs
	foreach my $key ( keys %attr ) {
		$Self->{$key} = $attr{$key};
	}
}

# ----------------------------------------------------------------------------
# method: message_length
#
# This method analyses a buffer and return the length of the first
# applicative message or -1 when the buffer does not contain any full message.
#
# This method needs to be overloaded for each new protocol or codec.
#
#    Parameters:
#       $buffer - binary buffer to analyze
# ----------------------------------------------------------------------------
sub message_length {
	my ( $Self, $buffer ) = @_;
	$Self->{Logger}->info("CODECs::message_length");
	die "CODEC is an abstract class, use derived class doing real work";
}

# ----------------------------------------------------------------------------
# method: decode
#
# decode a binary message and return a structured message.
#
# Parameters:
#     $bin - a complete binary applicative message
# ----------------------------------------------------------------------------
sub decode {
	my ( $Self, $bin ) = @_;
	$Self->{Logger}->info("CODECs::decode (" . bin2hexa ($bin) . ")");
	die "CODEC is an abstract class, use derived class doing real work";
}

# ----------------------------------------------------------------------------
# method: encode
#
# encode a structured message and return a binary buffer, or die when the supplied
# values doe not allow encoding. To support recursion Messages should contains all
# the required additional attributes.
#
# Parameters:
#     $msg - structured message to encode. 
# ----------------------------------------------------------------------------
sub encode {
	my $Self = shift;
	$Self->{Logger}->info("CODECs::encode");
	die "CODEC is an abstract class, use derived class doing real work";
}

# ----------------------------------------------------------------------------
# method: image
#
# Return the string image of a message
#
# Parameters:
#     $msg - binary buffer
# ----------------------------------------------------------------------------
sub image {
    my ( $Self, $msg ) = @_;
    
    my $decoded = $Self->decode($msg);
    return $decoded->dump();
}

1;
