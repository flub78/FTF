# ----------------------------------------------------------------------------
#
# Title: Class Events::Connector
#
# File - Events/Connector.pm
# Author - frederic
#
# Name:
#
#    package Events::Connector
#
# Abstract:
#
# Connectors are objects containing one or several Events with
# methods to handle data reception and transmission.
# Connector is the root of objects managed by the eventsManager class.
#
# - Network connections contains one handle that can be used for
# reading and writing. It is the socket descriptor.
#
# - File connection contains one file descriptor which is most often used
# either for reading or for writing.
#
# - Consoles reference STDIN and STDOUT. They use STDIN for input and STDOUT
# for output. I should consider the capacity to send data to stderr.
#
# - Programs manage 3 file descriptors, two connected to the program stdout
# and stderr and one connected to stdin.
#
# In our context conectors manage input and output buffers. They can be
# associated with codecs to find applicative messages boundaries.
#
# Connectors log every sent and receive data, at the binary stream level
# when the logger is set to *DEBUG*, at the application message level when the logger
# is set to *INFO*. In the latest case, the connector relies on a codec object
# to display the application message.
#
# Connectors maintain a list of destination, destinations are other connectors
# to who every received data is forwarded. This mechanism is very convenient
# to connect several connectors together and build very easily complex
# data flow. For example it is trivial to copy files by connecting together
# a file reader and a file writer. It is trivial to build a proxy by connecting
# a client service connection with a client connector, etc. You can also build
# complex data processing by connectiong together simple data processing modules.
#
# You are not really supposed to use connectors directly, you should use the
# connector children, or more likely, you should create classes derived from
# the connectors children.
#
# Do not forget that everything in the Events module has been designed to support
# simultaneous input and output on multiple sockets and file descriptors. So you
# should really avoid any blocking operations in the handlers. If you do it anyway
# you may freeze your application during IO operation or in worst cases deadlocks may occur.
#
# Connectors familly:
#
# (see Connectors.png)
#
# Block size:
#
# As we are in a test context, it is often required to check that the tested
# clients and servers are able to handle correctly messages splitted across
# several TCP/IP packets and multiple business messages packed inside a unique
# TCP/IP packet.
#
# To do that you can specify a *block_size* attribute for the connector. When
# this attribute is defined the send method wait to have *block_size* bytes to send
# before to send them. It also splits bigger messages.
# ----------------------------------------------------------------------------
package Events::Connector;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Exporter;
use Log::Log4perl;
use Data::Dumper;
use Events::EventsManager;
use CODECs;
use CODECs::Binary;
use Carp;
use ClassWithLogger;

$VERSION = 1;

@ISA = qw(ClassWithLogger);

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
	my $Self = shift;

    # Call the parent initialization first
    $Self->ClassWithLogger::_init(@_);

	my %attr = @_;
	$Self->debug("Connector::_init by $Self");

	# default, often replaced
	$Self->{'codec'} = new CODECs::Binary();

 # When block size is not null, the connector attempt to send data by block size
 # chunks.
	$Self->{'block_size'} = 0;

# When block size is not null, the data ready method wait to have enough data to
# fill a full block. However after a while the buffer must be sent anyway to
# avoid starvation.
	$Self->{'postponed'} = 0;

	$Self->{'id'}               = $Self;
	$Self->{'emulate_blocking'} = 0;

	# Takes the constructor parameters as object attributs
	foreach my $key ( keys %attr ) {
		$Self->{$key} = $attr{$key};
	}

	# Others initialisation
	# input buffer
	$Self->{inBuffer} = "";

	# output buffer
	$Self->{outBuffer} = "";

	# bytes and messages received and transmitted
	$Self->{'bytesReceived'}    = 0;
	$Self->{'bytesSent'}        = 0;
	$Self->{'messagesReceived'} = 0;
	$Self->{'messagesSent'}     = 0;

  # destination contains a list of connectors to which forward the received data
	$Self->{'destination'} = [];
}

# ----------------------------------------------------------------------------
# method: id
#
#    Returns a meaningful unique id for the connector. Is expected to return
#    something human readable like a filename, a host port IP address, etc.
# ----------------------------------------------------------------------------
sub id {
	my ($Self) = @_;

	return $Self->{'id'};
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

	$Self->debug("$Self->{'id'} connection closed");

	if ( exists( $Self->{'parent'} ) ) {
		$Self->{'parent'}->signal($Self);
	}
	if ( $Self->{'emulate_blocking'} ) {
        my $id = $Self->id();
        return signal($id, "");
    }
	
}

# ----------------------------------------------------------------------------
# method: send
#
#    Send an application message to the connector
#
#    Parameters:
#       $msg - string to send
# ----------------------------------------------------------------------------
sub send {
	my ( $Self, $msg ) = @_;

  # just hope that $msg is not binary if the codec is the default CODECs::Binary
	my $img = $Self->{'codec'}->image($msg);

	$Self->trace("snd -> $Self->{'id'} $img");
	$Self->{outBuffer} .= $msg;
	$Self->{'messagesSent'}++;
}

# ----------------------------------------------------------------------------
# method: receive
#
#    Emulate blocking receive
#
# Parameters:
#    $timeout - duration in seconds
#
# Returns:
#    an application message or undef in case of timeout
# ----------------------------------------------------------------------------
sub receive {
	my ( $Self, $timeout ) = @_;

	$Self->debug("receive(timeout=$timeout)");
	if ( $Self->{'emulate_blocking'} ) {
		my $id = $Self->id();
		return wait_for( $id, $timeout );
	}
	else {
		croak "Connector emulate_blocking must be set to call the receive method";
	}
}

# ----------------------------------------------------------------------------
# method: blocking_send
#
#    Send an application message to the connector
#
#    Parameters:
#       $msg - string to send
# ----------------------------------------------------------------------------
sub blocking_send {
    my ( $Self, $msg ) = @_;

  # just hope that $msg is not binary if the codec is the default CODECs::Binary
    my $img = $Self->{'codec'}->image($msg);

    $Self->trace("snd -> $img");
    
    my $handle = $Self->{'handle'}->{'write'}; 
    
    my $bytes_written = syswrite( $handle, $msg, length($msg) );
    $Self->{'bytesSent'} += $bytes_written;
    $Self->{'messagesSent'}++;
}

# ------------------------------------------------------------------------------
# routine: handle_send_err
# ------------------------------------------------------------------------------
sub handle_send_err {
	my ( $Self, $handle, $err_msg ) = @_;

print "handle_send_err ...............\n";

	$Self->error("Error while sending: $err_msg");
	Events::EventsManager::removeHandler( $Self, 'write' );
}

# ----------------------------------------------------------------------------
# method: data_received
#
#    Callback called when data are received. You probably do not need to change the provided one.
#
#    parameters:
#       $handle - from which data has been received
# ----------------------------------------------------------------------------
sub data_received {
	my ( $Self, $handle ) = @_;

	$Self->trace("Connector::data_received from $handle");

	my $data;
	my $bytes_read = sysread( $handle, $data, 1024 );

	if ( !defined($bytes_read) ) {
		$Self->trace("undefined bytes_read");
		return;
	}
	elsif ( $bytes_read == 0 ) {

		# Client closed socket. We do the same here, and remove
		# it from the readable_Events list
		$Self->trace("client has closed the connector");
		$Self->close();

		return;
	}

	# proceed data
	$Self->trace( "rcv <- $Self->{'id'} " . unpack( "H*", $data ) );
	$Self->{inBuffer} .= $data;
	$Self->{'bytesReceived'} += $bytes_read;
	$Self->trace( "input buffer length = " . length( $Self->{inBuffer} ) );

	# while they are complete messages in the buffer
	while (1) {

		my $len = $Self->{'codec'}->message_length( $Self->{inBuffer} );

		last if ( $len <= 0 );

		# found a full message
		my $msg = CODECs::pop_message( \$Self->{inBuffer}, $len );

		$Self->{'messagesReceived'}++;
		my $img = $Self->{'codec'}->image($msg);

		$Self->debug( "rcv <- $Self->{'id'} " . " $img" );
		if ( $Self->{'emulate_blocking'} ) {
			my $id = $Self->id();
			signal( $id, $msg );
		}
		$Self->messageReceived($msg);

		foreach my $dest ( @{ $Self->{'destination'} } ) {
			$dest->send($msg);
		}
	}
}

# ----------------------------------------------------------------------------
# method: err_received
#
#    Callback called when data are received. You probably do not need to change the provided one.
#
#    parameters:
#       $handle - from which data has been received
# ----------------------------------------------------------------------------
sub err_received {
	my ( $Self, $handle ) = @_;

	$Self->trace("Connector::err_received from $handle");

	my $data;
	my $bytes_read = sysread( $handle, $data, 1024 );

	if ( !defined($bytes_read) ) {
		$Self->trace("undefined bytes_read");
		return;
	}
	elsif ( $bytes_read == 0 ) {

		# Client has closed stderr. We do the same here, and remove
		# it from the readable_Events list
		$Self->trace("client has closed stderr ???");
		$Self->close();
		return;
	}

	# proceed data
	$Self->debug( "<- stderr $Self->{'id'} " . $data );
}

# ----------------------------------------------------------------------------
# method: data_ready
#
#    Callback called when data are ready to send. You probably do not need to
#    change the provided one.
#
#    parameters:
#       $handle - socket
# ----------------------------------------------------------------------------
sub data_ready {
	my ( $Self, $handle ) = @_;

	my $len = length( $Self->{outBuffer} );

	# return when there is nothing to send
	while ($len) {
		$Self->trace("data_ready, bytes to write = $len");

		if ( $Self->{'block_size'} ) {

			# check that we have at least block size bytes to send
			if ( $len >= $Self->{'block_size'} ) {

				# We are going to send only block size
				$len = $Self->{'block_size'};
			}
			else {

				# data to send is less than block size
			}
		}

		# send the data
		my $bytes_written = syswrite( $handle, $Self->{outBuffer}, $len );
		# $Self->trace("data_ready, bytes written = $bytes_written ");

		my $sent = substr( $Self->{outBuffer}, 0, $bytes_written );
		if ($sent) {
			$Self->trace( "snd -> $Self->{'id'} " . unpack( "H*", $sent ) );
		}

		if ( !defined($bytes_written) ) {
			if ( Events::EventsManager::err_will_block($!) ) {

				# Should happen only in deferred mode.
				# Event handler should already be set, so we will
				# be called back eventually, and will resume sending
				return 1;
			}
			else {    # Uh, oh
				$Self->handle_send_err( $handle, $! );
				return 0;    # fail. Message remains in queue ..
			}
		}

		$Self->{'bytesSent'} += $bytes_written;

		# truncate the buffer
		$Self->{outBuffer} = substr( $Self->{outBuffer}, $bytes_written );

		return if ( $bytes_written != $len );
		$len = length( $Self->{outBuffer} );
	}

	# everything has been written
	$Self->{outBuffer} = "";
	Events::EventsManager::removeHandler( $Self, 'write' );
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

# ----------------------------------------------------------------------------
# method: connected
#
#    Callback activated when the communication with the peer has been
#    established. You should overload this method to send the first message
#    of the communication.
# ----------------------------------------------------------------------------
sub connected {
	my ($Self) = @_;

	$Self->debug("$Self->{'id'} connected");
}

sub messagesReceivedNumber { return $_[0]->{'messagesReceived'}; }
sub messagesSentNumber     { return $_[0]->{'messagesSent'}; }
sub bytesReceived          { return $_[0]->{'bytesReceived'}; }
sub bytesWritten           { my $Self = shift; return $Self->{'bytesSent'}; }

# ----------------------------------------------------------------------------
# method: addDestination
#
#    This method add the connection handler in the list of desitation.
#    When messages are received they are broadcasted to the list of
#    destinations. Their send method is called. It is a very convenient
#    way to connect together files, clients, servers, etc.
#
# Parameters:
#    $receiver - handler to which messages will be sent
# ----------------------------------------------------------------------------
sub addDestination {
	my ( $Self, $receiver ) = @_;

	$Self->trace("addDestination $receiver");
	push( @{ $Self->{'destination'} }, $receiver );
}

1;
