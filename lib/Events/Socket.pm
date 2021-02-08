# ----------------------------------------------------------------------------
#
# Title: Class Events::Socket
#
# File - EventsClient.pm
# Author - frederic
#
# Name:
#
#    package Events::Socket
#
# Abstract:
#
#    UDP/IP or TCP/IP clients. These clients are registered
#    by the <EventManager> and called back when related
#    events happen.
# ----------------------------------------------------------------------------
package Events::Socket;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Events::Connector;
use IO::Socket::INET;
use IO::Socket::SSL qw(inet4);

$VERSION = 1;

@ISA = qw(Events::Connector);

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    $Self->{'ssl'} = 0;
    $Self->Events::Connector::_init(@_);

    if ( exists( $Self->{socket} ) ) {
        Events::EventsManager::registerHandler( $Self, $Self->{socket},
            'read' );

        $Self->{'id'} = "("
          . $Self->{'socket'}->peerhost() . ":"
          . $Self->{'socket'}->peerport() . ")";

        $Self->connected();
    }
}

# ----------------------------------------------------------------------------
# method: connect
#
#    Connect to a server
#
#    Parameters:
#       $host - name of the server to connect to
#       $port - port number
#       $proto - 'udp' or 'tcp'
# ----------------------------------------------------------------------------
sub connect {
    my ( $Self, $host, $port, $proto ) = @_;

    unless ( defined($proto) ) {
        $proto = 'tcp';
    }

    # Create a new internet socket
    if ( $Self->{'ssl'} ) {
        $Self->{socket} = IO::Socket::SSL->new(
            PeerAddr        => $host,
            PeerPort        => $port,
            Proto           => $proto,
            SSL_verify_mode => 0
        );
    }
    else {
        $Self->{socket} = IO::Socket::INET->new(
            PeerAddr => $host,
            PeerPort => $port,
            Proto    => $proto
        );
    }
    
    ( $Self->{socket} ) or die "connection failed: $@";

    Events::EventsManager::registerHandler( $Self, $Self->{socket}, 'read' );
    $Self->{'id'} = "("
      . $Self->{'socket'}->peerhost() . ":"
      . $Self->{'socket'}->peerport() . ")";

    $Self->connected();
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

    close( $Self->{socket} );
    $Self->Events::Connector::close();
    Events::EventsManager::removeHandler( $Self, 'read' );
    Events::EventsManager::removeHandler( $Self, 'write' );
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

    Events::EventsManager::registerHandler( $Self, $Self->{socket}, 'write' );
    Events::EventsManager::set_non_blocking( $Self->{socket} );
    $Self->{socket}->autoflush();
}

1;
