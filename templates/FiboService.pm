# ----------------------------------------------------------------------------
# Title: Class FiboService
#
# Source - <file:../FiboService.pm.html>
#
# Name:
#
#    package FiboService
#
# Abstract:
#
#    This is an example of TCP/IP client connections. Each time that
#    a client is accepted a connection is created to handle it.
# ----------------------------------------------------------------------------
package FiboService;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Events::Socket;
use Events::EventsManager;
use Data::Dumper;

$VERSION = 1;
@ISA     = qw(Events::Socket);

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
	my $Self = shift;

	# Call the parent constructor
	$Self->Events::Socket::_init(@_);

	# message queue for postponed output messages
	$Self->{'postponed'}     = [];
	$Self->{'timeoutNumber'} = 0;
}

# ------------------------------------------------------------------------
# routine: fibo
#
# Compute the Fibonnaci value. Around 2 sec for fibo(30)
#
# ------------------------------------------------------------------------
sub fibo {
	my $n = shift;

	if ( ( $n == 0 ) || ( $n == 1 ) ) {
		return 1;
	}
	else {
		return fibo( $n - 1 ) + fibo( $n - 2 );
	}
}

# Callbacks
# ---------

# ----------------------------------------------------------------------------
# method: ansynchronous_send
#
#    Emulate an asynchronous server. Instead of sending the message immediatly,
#    the message is pushed in a queue that will be processed later.
#    To avoid the first in, first out effect, message are extracted randomely from
#    head or from tail of the queue.
#
#    Parameters:
#       $msg - binary buffer truncated to a full and unique application message
# ----------------------------------------------------------------------------
sub asynchronous_send {
	my ( $Self, $msg ) = @_;

	push( @{ $Self->{'postponed'} }, $msg );

	if ( scalar( @{ $Self->{'postponed'} } ) == 1 ) {
		# There is only one message in the queue
		# start a 1 second timer
		$Self->{'delay'} = 1;
		Events::EventsManager::registerTimer( $Self, $Self->{'delay'},
			$Self->{'periodic'} );
	}
}

# ----------------------------------------------------------------------------
# method: timeout
#
#    Asynchronous mode emulation. All message which have been pushed 
#    during the last second are sent in random order.
# ----------------------------------------------------------------------------
sub timeout {
	my ($Self) = @_;

	$Self->{'timeoutNumber'}++;
	$Self->info("Timeout $Self->{name}");

	my $msg;
	while ( @{ $Self->{'postponed'} } ) {    
		    # randomely extract the message from head or tail
		if ( int( rand(100) ) > 50 ) {
			# last value
			$msg = pop( @{ $Self->{'postponed'} } );
		}
		else {
			# first value
			$msg = shift( @{ $Self->{'postponed'} } );
		}
		# send it
		$Self->send($msg);
	}
}

# ----------------------------------------------------------------------------
# method: messageReceived
#
#    Callback activated when a full application message has been received.
#
#    Parameters:
#       $msg - binary buffer truncated to a full and unique application message
# ----------------------------------------------------------------------------
sub messageReceived {
	my ( $Self, $msg ) = @_;

	$Self->info("<- $msg");

	if ( $msg =~ /(\d*)/ ) {
		my $res = fibo($1);

		# Emulate a randomely buggy server
		if ( $Self->{'fail'} ) {
			if ( int( rand(100) ) > 70 ) {
				$res += 1;
			}
		}
		
		# Build the reply
		my $msg = "fibo ($1) = $res";
		$Self->warn($msg);

		# and send it, immediatly or not
		if ( $Self->{'async'} ) {
			$Self->asynchronous_send("$msg\n");
		}
		else {
			$Self->send("$msg\n");
		}
	}
	else {
		# error, not a number
		$Self->error("invalid request $msg");
	}
}

1;
