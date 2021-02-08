# ----------------------------------------------------------------------------
#
# Title:  Class Utilities
#
# File - Protocol/Utilities.pm
# Version - 1.0
#
# Name:
#
#       package Protocol::Utilities
#
# Abstract:
#
#       Set of low level methods used by the protocol management layer.
#       Those methods are often nothing more than the renaming of perl
#       facilities, they are mainly used to ehance readibility for 
#       people who are not Perl specialists.
# ------------------------------------------------------------------------
package Protocol::Utilities;

use strict;

use Exporter;
use Log::Log4perl;
use Data::Dumper;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

@ISA = qw (Exporter);
$VERSION = 1;
@EXPORT = qw (bin2hexa hexa2bin existIn at_offset pop_message);

# ------------------------------------------------------------------------
# routine: existIn
#
# Check than an element exist in a list.
#
# Parameters:
# elt - elt to check
# list - list to check
# Return: a boolean value
# ------------------------------------------------------------------------
sub existIn {
    my ( $elt, @list ) = @_;

    foreach my $s (@list) {
        if ( $s eq $elt ) {
            return 1;
        }
    }
    return 0;
}

# ------------------------------------------------------------------------
# routine: bin2hexa
#
# Converts a binary buffer into an hexadecimal representation
#
# Parameters:
# buffer - String to convert
# 
# Return: an hexadecimal string value
# ------------------------------------------------------------------------
sub bin2hexa {
    my ( $buffer) = @_;

    my ($hex) = unpack ("H*", $buffer);
    return $hex;
}

# ------------------------------------------------------------------------
# routine: hexa2bin
#
# Converts an hexadecimal representation into a binary buffer
#
# Parameters:
# hexa - string to convert
# 
# Return: a binary value
# ------------------------------------------------------------------------
sub hexa2bin {
    my ($hexa) = @_;

    my ($bin) = pack ("H*", $hexa);
    return $bin;
}

# ------------------------------------------------------------------------
# routine: at_offset
#
# byte access into a binary buffer
#
# Parameters:
# buffer - binary buffer
# offset - byte offset into the buffer
# Return: a value between 0 and 255
# ------------------------------------------------------------------------
sub at_offset {
    my ( $buffer, $offset) = @_;

    return unpack("x$offset C",$buffer); 
}

# ------------------------------------------------------------------------
# routine: pop_message
#
# extract a message from the head of a buffer and truncate the buffer
#
# Parameters:
#    $buffer_ref - a reference to a binary buffer
#    $len - length of the chunk to remove from the head of the message
# ------------------------------------------------------------------------
sub pop_message {
    my ( $buffer_ref, $len ) = @_;

    my $msg = substr( $$buffer_ref, 0, $len );
    $$buffer_ref = substr( $$buffer_ref, $len );
    return $msg;
}

1;
