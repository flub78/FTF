# ----------------------------------------------------------------------------
#
# Title:  Class Client
#
# Name:
#
#       package Network::Client
#
# Abstract:
#
#       Encapsulation around IO::Socket::INET. It should be used
#       for blocking access to sockets. The class provides standardized
#       support for low and high level IO logging. It uses the CODEC
#       services to determine the boundaries of application messages
#       and perform high level message logging.
# ------------------------------------------------------------------------
package Network::Client;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use Exporter;
use Log::Log4perl;
use Data::Dumper;
use IO::Socket;
use CODECs;
use CODECs::Binary;

$VERSION = 1;

@ISA = qw(Exporter);

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

	# likely replaced by user
    $Self->{'codec'} = new CODECs::Binary();

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    # Others initialisation
    $Self->{inBuffer} = "";
    unless ( exists( $Self->{'id'} ) ) {
        $Self->{'id'} = "($Self->{'PeerAddr'}:$Self->{'PeerPort'})";
    }
    $Self->{'sock'} = new IO::Socket::INET(
        PeerAddr => $Self->{'PeerAddr'},
        PeerPort => $Self->{'PeerPort'},
        Proto    => $Self->{'Proto'}
    );
    # $Self->{'sock'}->autoflush();
    die "Socket could not be created. Reason: $!\n" unless $Self->{'sock'};
    $Self->{Logger}->debug("$Self->{'id'} connected");
}

# ------------------------------------------------------------------------
# method: send
#
# Send data over a socket and trace it
#
# Parameters:
# $sock - socket
# $buf  - buffer to send
# ------------------------------------------------------------------------
sub send {
    my ( $Self, $msg ) = @_;

    # high level traces
    my $img = $Self->{'codec'}->image($msg);
    $Self->{'Logger'}->info( "-> $Self->{'id'} " . $img );

    # low level traces
    $Self->{'Logger'}->debug( "-> $Self->{'id'} " . unpack( "H*", $msg ) );

    my $sock = $Self->{'sock'};
    print $sock $msg;
}

# ------------------------------------------------------------------------
# method: receive
#
# Loop over the socket reading and returns a full message when one is
# recognize.
#
# Parameters:
# $sock - socket
#
# Returns:
# a full applicative message
# ------------------------------------------------------------------------
sub receive {
    my ($Self) = @_;

    my $sock = $Self->{'sock'};

    # Look if there is already a full message in the input buffer
    my $len = $Self->{'codec'}->message_length( $Self->{inBuffer} );

    # read new data as long that we have not a full message
    my $buf;
    while ( $len <= 0 ) {
        # $buf = <$sock>;
        return unless(sysread($sock, $buf, 100));
        $Self->{inBuffer} .= $buf;

        # low level traces
        $Self->{'Logger'}->debug( "<- $Self->{'id'} " . unpack( "H*", $buf ) );
        $len = $Self->{'codec'}->message_length( $Self->{inBuffer} );
    }

    # found a full message
	my $msg = CODECs::pop_message (\$Self->{inBuffer}, $len);
    
    # high level traces
    my $img = $Self->{'codec'}->image($msg);
    $Self->{'Logger'}->info( "<- $Self->{'id'} " . $img );
    return $msg;
}

# ------------------------------------------------------------------------
# method: close
#
# Close the socket
# ------------------------------------------------------------------------
sub close {
    my ($Self) = @_;
    close( $Self->{'sock'} );
    $Self->{'Logger'}->info("$Self->{'id'} connection closed");
}

1;
