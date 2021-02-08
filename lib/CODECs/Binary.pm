# ----------------------------------------------------------------------------
#
# Title: Class CODECs::Binary
#
# File - CODECs::Binary.pm
# Author - frederic
#
# Name:
#
#    package CODECs::Binary
#
# Abstract:
#
# Binary CODEC; It is not really a codec. Every received binary
# message is considered as a message. Messages are just dumped
# in hexadecimal in the image function. This codec is the default when
# none is defined.
# ----------------------------------------------------------------------------
package CODECs::Binary;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Exporter;
use Log::Log4perl;

$VERSION = 1;

@ISA = qw(Exporter);

# ------------------------------------------------------------------------
# method: new
#
# Returns a new initialised object for the class.
# ------------------------------------------------------------------------
sub new {
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

	# Others initialisation
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

	return length($buffer);
}

# ----------------------------------------------------------------------------
# method: image
#
# Returns an ASCII, human readable image of the object. This method is used
# each time that a class of the Framework needs to dump an object. It is
# recommended to display all the information contained in the message.
# ----------------------------------------------------------------------------
sub image {
	my ($Self, $msg) = @_;
	
	return unpack( "H*", $msg );	
}

1;
