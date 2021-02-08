# ----------------------------------------------------------------------------
#
# Title: Class Events::File
#
# File - Events/File.pm
# Author - frederic
#
# Name:
#
#    package Events::File
#
# Abstract:
#
#    File connector.
#
# ----------------------------------------------------------------------------
package Events::File;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Events::Connector;

$VERSION = 1;

@ISA = qw(Events::Connector);


# ----------------------------------------------------------------------------
# method: open
#
#    open a file
#    
#    Parameters:
#       $name - filnename
#       $mode - "<" or ">"
# ----------------------------------------------------------------------------
sub open {
    my ($Self, $name, $mode) = @_;
    
    # Create a new file descriptor
    my $fd;
    open ($fd, $mode . $name) or die ("cannot open file $name!");
    $Self->{fd} = $fd;
   ($fd) or die "open of $name failed";
   
    if ($mode eq "<") {   
        Events::EventsManager::registerHandler( $Self, $Self->{fd}, 'read' );
    }    
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
	
	Events::EventsManager::registerHandler( $Self, $Self->{fd}, 'write' );
	Events::EventsManager::set_non_blocking( $Self->{fd} );
	$Self->{fd}->autoflush();
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

	close ($Self->{fd});
	$Self->Events::Connector::close();
	Events::EventsManager::removeHandler( $Self, 'read' );
	Events::EventsManager::removeHandler( $Self, 'write' );
}

1;
