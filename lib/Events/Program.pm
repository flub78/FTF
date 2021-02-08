# ----------------------------------------------------------------------------
#
# Title: Class Events::Program
#
# File - Events/Program.pm
# Author - frederic
#
# Name:
#
#    package Events::Program
#
# Abstract:
#
#    Program connector. It can be used to control another program.
#
# ----------------------------------------------------------------------------
package Events::Program;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Log::Log4perl;

use Events::Connector;
use IPC::Open3;
use FileHandle;

$VERSION = 1;

@ISA = qw(Events::Connector);


# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift; 

    my %attr = @_;

    $Self->Events::Connector::_init(@_);

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    # Others initialisation
    exists($Self->{'cmd'}) or die "undefined 'cmd' parameter";

    $Self->trace("Executing $Self->{'cmd'}");
    
    $Self->{'id'} = "(program:" . $Self->{'cmd'} . ")";
    $Self->{'StdinHandle'}  = FileHandle->new();
    $Self->{'StdoutHandle'} = FileHandle->new();
    $Self->{'StderrHandle'} = FileHandle->new();
    
    $Self->{'pid'} = open3 ($Self->{'StdinHandle'},
                            $Self->{'StdoutHandle'},
                            $Self->{'StderrHandle'},
                            $Self->{'cmd'});
    die "Could not execute: $!" unless $Self->{'pid'};
    
    Events::EventsManager::registerHandler($Self, $Self->{'StdoutHandle'}, 'read');    
    Events::EventsManager::registerHandler($Self, $Self->{'StderrHandle'}, 'error');
}

# ----------------------------------------------------------------------------
# method: close
#
#    Close the connection. This method is called by the event manager
#    when the peer closes the connection. It can also be used to close
#    the connection from the client side.
# ----------------------------------------------------------------------------
sub close {
	my ($Self) = @_;

	$Self->Events::Connector::close();
	Events::EventsManager::removeHandler( $Self, 'read' );
	Events::EventsManager::removeHandler( $Self, 'write' );
	Events::EventsManager::removeHandler( $Self, 'error' );
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
	
	Events::EventsManager::registerHandler( $Self, $Self->{'StdinHandle'}, 'write' );
	Events::EventsManager::set_non_blocking( $Self->{'StdinHandle'} );
	$Self->{'StdinHandle'}->autoflush();
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

}

1;
