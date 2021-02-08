# ----------------------------------------------------------------------------
#
# Title: Class Events::Console
#
# File - EventsConsole.pm
# Author - frederic
#
# Abstract:
#
#    Console connector. This connector can read from the standard input 
#    (keyboard) and write to the process standard output. As all the 
#    connectors it register to the event manager to allow simultaneous access
#    from other connectors.
# ----------------------------------------------------------------------------
package Events::Console;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Events::Connector;

$VERSION = 1;

@ISA = qw(Events::Connector);


# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    $Self->Events::Connector::_init(@_);
    
    $Self->{socket} = \*STDOUT;
    Events::EventsManager::registerHandler( $Self, \*STDIN, 'read' );
    Events::EventsManager::registerHandler( $Self, \*STDOUT, 'write' );
}

# ----------------------------------------------------------------------------
# method: send
#
#    Send a request to the server. When a timeout is specified, the send is blocking.
#
#    Parameters:
#       $msg - string to send
#       $timeout - when defined, the call becomes blocking
#
# ----------------------------------------------------------------------------
sub send {
	my ( $Self, $msg, $timeout ) = @_;

	Events::Connector::send(@_);
	
	Events::EventsManager::registerHandler( $Self, \*STDOUT, 'write' );
	Events::EventsManager::set_non_blocking( \*STDOUT );
	\*STDOUT->autoflush();
}

1;
