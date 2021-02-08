# ----------------------------------------------------------------------------
#
# Title: Class CODECs::Telnet
#
# File - CODECs::Telnet.pm
# Author - frederic
#
# Name:
#
#    package CODECs::Telnet
#
# Abstract:
#
# Telnet CODEC
#
# ----------------------------------------------------------------------------
package CODECs::Telnet;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use CODECs;
use Log::Log4perl;

$VERSION = 1;

@ISA = qw(CODECs);

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
# The provided example is telnet compliant, it returns the length of the
# the first line terminated by an end of line character.
#
#    Parameters:
#       $buffer - binary buffer to analyze
# ----------------------------------------------------------------------------
sub message_length {
	my ( $Self, $buffer ) = @_;

	# size of the first line terminated by \n
	if ( $buffer =~ /(.*)\n/ ) {
		# \n terminated line
		return length($1) + 1;
	}
	else {
		# no full line
		return -1;
	}
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
	
	# for Telnet protocol, each line is already human readable.
	return $msg;	
}

1;
