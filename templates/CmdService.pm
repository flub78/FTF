# ----------------------------------------------------------------------------
# Title: Class CmdService
#
# Source - <file:../CmdService.pm.html>
#
# Name:
#
#    package CmdService
#
# Abstract:
#
#    This class manages sessions for an interactive telnet service.
#    Each time that a telnet client connects to the server an object
#    of this type is activated.
#
#    The server manages an optional prompt and recognize line oriented
#    commands.
#
#    Among thes commands:
#    help - prints the list of recognized commands
#    quit -stop the server
# ----------------------------------------------------------------------------
package CmdService;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use lib "$ENV{'FTF'}/lib";
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
	$Self->prompt();
}


# ------------------------------------------------------------------------
# routine: prompt
#
# send the prompt to the client
#
# ------------------------------------------------------------------------
sub prompt {
	my ($Self) = @_;

	if ( exists($Self->{'prompt'})) {
		$Self->send("\n" . $Self->{'prompt'});
	}
}

# ------------------------------------------------------------------------
# routine: help
#
# send the online help to the client
#
# ------------------------------------------------------------------------
sub help {
    my ($Self, $param) = @_;

    my $hlp;
    if ($param eq "help") {
    	$hlp = "Help command display global or command help.
    	type help for the list of commands.
    	type help command for the command help
    	";
    } elsif ($param eq "quit") {
        $hlp = "Quit command stops the server and exit.";
    	
    } else {
        $hlp = "Telnet command interpretor
    
    recognized command:
        help [param] : displays global or command help
        quit : stop the server
    ";
    }
    
    $Self->send("\n" . $hlp);
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
	$Self->{Logger}->info("Timeout $Self->{name}");

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

    $msg = substr($msg, 0, -2);    # remove CR/LF
	$Self->{Logger}->info("<- $msg");

    if ($msg =~ /help\s*(\w*)/) {
        $Self->help($1);
        
    } elsif ($msg eq "quit") {
    	print "server shut down by client\n";
    	exit (1);
    
    } else {
        $Self->send("unrecognized command");
    }
    $Self->prompt();

}

1;
