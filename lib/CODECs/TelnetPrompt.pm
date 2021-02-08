# ----------------------------------------------------------------------------
#
# Title: Class CODECs::TelnetPrompt
#
# File - CODECs::TelnetPrompt.pm
# Author - frederic
#
# Name:
#
#    package CODECs::Telnet
#
# Abstract:
#
# This codec is used for telnet oriented protocol in which the server terminates
# the message by a and end of line followed by a prompt.
#
# Telent is a line oriented protocol, this one is more block of lines  oriented.
# ----------------------------------------------------------------------------
package CODECs::Telnet;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use CODECs;
use Log::Log4perl;
use Carp;

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

    (exists( $Self->{'prompt'} ) ) or croak "missing \'prompt\' string";

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

    # print "message_length ($buffer)\n";
	# size of the first line terminated by \n
	my $prompt = $Self->{'prompt'};
	if ( $buffer =~ /^(.*)\n\>\s/mo ) {

        my $txt = $1;
 		# \n terminated line
		my $len = length($txt) + 1 + length($prompt);
        # print "match ($txt) $len\n";
        
        # the following line is a bug it does not work when several lines are packed.
        # currently I am not able to find a correct regular expression to match
        # everything up to the prompt. I match only 3 chars.
		return length($buffer);
	}
	else {
		# no full message
		# print "does not match\n";
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
