# ----------------------------------------------------------------------------
#
# Title: Class Events::ProxyService
#
# File - EventsProxyService.pm
# Author - frederic
#
# Name:
#
#    package Events::ProxyService
#
# Abstract:
#
#    Manages a proxy service. When a client connects, the object
#    open itself a connection with a server and transmit all the
#    received data.
# ----------------------------------------------------------------------------
package Events::ProxyService;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Log::Log4perl;
use Events::Socket;
use Events::Socket;

$VERSION = 1;

@ISA = qw(Events::Socket);

# ----------------------------------------------------------------------------
# method: connected
#
#    Callback activated when the communication with the peer has been 
#    established. You should overload this method to send the first message
#    of the communication.
# ----------------------------------------------------------------------------
sub connected {
    my ( $Self) = @_;

    
    # $Self->debug("($Self->{'host'}:$Self->{'port'}) connected");
    $Self->{'client'} = new Events::Socket();
     
    # establish cross forwarding
    $Self->{'client'}->addDestination($Self);
    $Self->addDestination($Self->{'client'});
    
    # and connect
    $Self->{'client'}->connect($Self->{'host'}, $Self->{'port'});

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

    $Self->Events::Socket::close(@_);
    $Self->{'client'}->close();
}

1;
