# ----------------------------------------------------------------------------
#
# Title: Class Events::EchoService
#
# File - EventsEchoService.pm
# Author - frederic
#
# Name:
#
#    package Events::EchoService
#
# Abstract:
#
#    TCP/IP clients and servers with an object interface. This layer is the common part between servers and clients.
#
# ----------------------------------------------------------------------------
package Events::EchoService;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Log::Log4perl;
use Events::Socket;

$VERSION = 1;

@ISA = qw(Events::Socket);

# ----------------------------------------------------------------------------
# method: messageReceived
#
#    Callback activated when a full application message has been received.
#    
#    Parameters:
#       $msg - binary buffer truncated to a full and unique application message
# ----------------------------------------------------------------------------
sub messageReceived {
    my ($Self, $msg) = @_;
    
    $Self->info ("<- $msg");

    # check for ctrl-d
    if (unpack("H*", $msg) eq "040d0a") {
        $Self->close();
    } 
    
    # send it back
    $Self->send($msg);
    $Self->prompt();
}

# ----------------------------------------------------------------------------
# method: connected
#
#    Callback activated when the communication with the peer has been 
#    established. You should overload this method to send the first message
#    of the communication.
# ----------------------------------------------------------------------------
sub connected {
    my ( $Self) = @_;

    $Self->info("connected");
    $Self->prompt();
}

# ----------------------------------------------------------------------------
# method: prompt
#
#    Send a prompt to the peer.
# ----------------------------------------------------------------------------
sub prompt {
    my ( $Self) = @_;

    $Self->send("\n> ");
}

1;
