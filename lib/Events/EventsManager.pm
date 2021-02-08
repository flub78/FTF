# ----------------------------------------------------------------------------
#
# Title: Class Events::EventsManager
#
# File - EventsEventsManager.pm
# Author - frederic
#
# Name:
#
#    package EventsManager
#
# Abstract:
#
#    Events manager. Object oriented event loop manager.
#    Objects containing a file descriptor or socket can register
#    with the event manager. These objects have a set of
#    standardized methods which are called back when events happen.
#
#    It is a simple layer around the select routine. This
#    package must be a singleton, so it is a module, not a class.
#
#    The main difference between this module and others messaging or
#    event toolkits is that this one register regular perl objects
#    instead of simple routines. These objects must have the following methods:
#
#    data_received - invoked when data has been received.
#    data_ready - invoked when it is possible to send data.
#    timeout - invoked for timers and action timeout
#
#    I found more convenient to register objects than routine because
#    it is easier to associate context with objects. It makes applications
#    with multiple servers and clients simpler to write.
#
# Supported handler objects:
#    Events::File - support for regular files
#    Events::Server - TCP/IP servers
#    Events::Connector - TCP/IP client services
#    Events::UDPReader - UDP/IP listener
#    Events::Socket - UDP/IP and TCP/IP clients
#    Events::Program - control of programs
#
# Support for user events:
#
#    Events processing is a very efficient mechanisme to handle
#    multiple sources of information without multi thread hassle.
#    It is computing resources efficient and provides a natural mutual
#    exclusion mecanisme. Inside a handler the programer has not to cope
#    with mutual exclusion, he as the guarantee that only the handler is executing.
#
#    The counter part of the problem is that the logic of the application has
#    to be dispatched among multiple handlers which have to colaborate to
#    run the application. Often the program logic is controled by a states machine
#    automaton and each event triggers a transition.
#
#    I have provided two methods to keep the illusion of a sequential program 
#    event within an event programing context. The idea is only applicable with
#    a sequential program like a test for example, which have to interact 
#    sequentialy with several event driven actors, TCP/IP client and servers, 
#    timers, etc. The two methods are wait_for and signal.
#
#    Normally, the main program declares the event handlers and then starts the event loop.
#    
#    <Events.EventsManager.wait_for> has been designed to be call by the main program directly or indirectly.
#    It is just a loop around the event processing loop, which only exists when a specific
#    event has been signaled.
#
#    <Events.EventsManager.signal> should be called from an event handler, its function is to unblock
#    the main program which is supposed to perform the processing next step and then
#    to block again around the wait_for or event processing loop.
#
#    With this method at least the main program processing still look sequential 
#    and is so easy to read and understand.
#
#    Currently this kind of events are only indentified by a string, there is no counter
#    and when an event is taken into account by wait_for it is disabled, whatever
#    the number of handler who have signaled it. It means that it works well with
#    the main program waiting for events uniquely posted by a single handler.
#
#    If a more sophisticated implementation is required later, I'll do it at this time. 
#
# (see EventsClasses.png)
#
# ----------------------------------------------------------------------------
package Events::EventsManager;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Exporter;
use Log::Log4perl;

use Fcntl ":Fcompat";
use Event qw(loop unloop);

@ISA    = qw(Exporter);
@EXPORT = qw(eventLoop stopLoop after wait_for signal);

my $blocking_supported = 0;
my $log                = Log::Log4perl::get_logger("Events");
my $pendings = {};

# ----------------------------------------------------------------------------
# method: eventLoop
#
#    Main event processing loop.
# ----------------------------------------------------------------------------
sub eventLoop {
#	$log->trace("entering eventLoop");
	loop @_;
}

# ----------------------------------------------------------------------------
# method: stopLoop
#
#    Stop the event processing loop.
# ----------------------------------------------------------------------------
sub stopLoop {
	unloop;
}

# ----------------------------------------------------------------------------
# routine: _read (private)
#
#     Service method to read file descriptors
# ----------------------------------------------------------------------------
sub _read {
	my ($e) = @_;

	my $connector = $e->w->data();
	$connector->data_received( $connector->{'handle'}->{'read'} );
}

# ----------------------------------------------------------------------------
# routine: _err (private)
#
#     Service method to read stderr
# ----------------------------------------------------------------------------
sub _err {
	my ($e) = @_;

	my $connector = $e->w->data();
	$connector->err_received( $connector->{'handle'}->{'error'} );
}

# ----------------------------------------------------------------------------
# routine: _write (private)
#
#     Service method to write file descriptors
# ----------------------------------------------------------------------------
sub _write {
	my ($e) = @_;

	my $connector = $e->w->data();
	$connector->data_ready( $connector->{'handle'}->{'write'} );
}

# ----------------------------------------------------------------------------
# method: registerHandler
#
#    Register a handler object. In this library real Perl objects are
#    resistered as handler, that way it is easier to store contexts
#    associated with the objects.
#
#    These objetcs are supposed to have the following methods:
#
#    data_received - when something has been received
#    data_ready    - when it is possible to write on the handle
#    handle_send_error - when something bad has happened during sent
#    timeout -
#
#    Parameters:
#       $handler - object called back
#       $handle  - socket or file descriptor
#       $type    - 'read' or 'write'
# ----------------------------------------------------------------------------
sub registerHandler {
	my ( $handler, $handle, $type ) = @_;

	$log->trace("registerHandler, $handler, $handle, $type");

	$handler->{'handle'}->{$type} = $handle;
	if ( $type eq "write" ) {
		$handler->{'writeWatcher'} = Event->io(
			fd   => $handle,
			cb   => \&_write,
			data => $handler,
			poll => "w"
		);
	}
	elsif  ( $type eq "read" ) {
		$handler->{'readWatcher'} = Event->io(
			fd   => $handle,
			cb   => \&_read,
			data => $handler,
			poll => "r"
		);
	} elsif  ( $type eq "error" ) {
		$handler->{'readWatcher'} = Event->io(
			fd   => $handle,
			cb   => \&_err,
			data => $handler,
			poll => "r"
		);
	} 
}

# ----------------------------------------------------------------------------
# method: removeHandler
#
#    Unregister an handler object
#
#    Parameters:
#       $handle - socket or file descriptor
#       $type - 'read' or 'write'
# ----------------------------------------------------------------------------
sub removeHandler {
	my ( $handler, $type ) = @_;

#	$log->trace("removeHandler($handler, $type)");

	if ( $type eq "write" ) {
		if ( exists( $handler->{'writeWatcher'} ) ) {
			$handler->{'writeWatcher'}->cancel();
		}
	}
	else {
		if ( exists( $handler->{'readWatcher'} ) ) {
			$handler->{'readWatcher'}->cancel();
		}
	}
}

# ----------------------------------------------------------------------------
# routine: _timer (private)
#
#     Service method for timers timeout.
# ----------------------------------------------------------------------------
sub _timer {
	my ($e) = @_;

	my $timer = $e->w->data();
	$timer->timeout();
}

# ----------------------------------------------------------------------------
# method: registerTimer
#
#    Register a Timer object.
#
#    Timers must have a timeout method.
#
#    Parameters:
#       $timer  - object called back
#       $delay  - relative time for the timer
#       $repeat     - periodic or not
# ----------------------------------------------------------------------------
sub registerTimer {
	my ( $timer, $delay, $repeat ) = @_;

	my $abstime = time() + $delay;
	$repeat = 0 unless (defined($repeat));
	$log->debug("registerTimer($timer, $delay, $repeat): abstime = $abstime at " . time() );

	$timer->{'watcher'} = Event->timer(
		prio      => 2,
		interval  => $delay,
		cb        => \&_timer,
		repeat    => $repeat,
		data      => $timer,
		reentrant => 0
	);
}

# ----------------------------------------------------------------------------
# routine: _after (private)
#
#     Service method for "after" timeout.
# ----------------------------------------------------------------------------
sub _after {
	my ($e) = @_;

	my $cmd = $e->w->data();
	if ($cmd) {
		&{$cmd};
	}
	else {
		unloop;
	}
}

# ----------------------------------------------------------------------------
# method: after
#
#    Execute an eval after a delay
#
#    Parameters:
#       $delay  - relative time for the timer
#       $cmd    - command to execute
# ----------------------------------------------------------------------------
sub after {
	my ( $delay, $cmd ) = @_;

	Event->timer(
		prio      => 2,
		at        => time + $delay,
		cb        => \&_after,
		repeat    => 0,
		data      => $cmd,
		reentrant => 0
	);
	loop unless ($cmd);
}

# ----------------------------------------------------------------------------
# method: removeTimer
#
#    Unregister an Timer object
#
# ----------------------------------------------------------------------------
sub removeTimer {
	my ($timer) = @_;

	$log->trace("removeTimer ($timer)");

	$timer->{'watcher'}->cancel();
}

# Support for nonblocking I/O
# ---------------------------
BEGIN {

	# blocking is supported at least on Linux and Windows.
	eval {
		require POSIX;
		POSIX->import(qw(F_SETFL O_NONBLOCK EAGAIN));
	};
	$blocking_supported = 1 unless $@;
}

# ------------------------------------------------------------------------------
# routine: _err_will_block (private)
# ------------------------------------------------------------------------------
sub err_will_block {

	if ($blocking_supported) {
		return ( $_[0] == EAGAIN() );
	}
	return 0;
}

# ------------------------------------------------------------------------------
# routine: set_non_blocking
# ------------------------------------------------------------------------------
sub set_non_blocking {

	my $sock = shift;
	if ($blocking_supported) {

		# preserve other fcntl flags
		my $flags = fcntl( $sock, F_GETFL(), 0 );
		fcntl( $sock, F_SETFL(), $flags | O_NONBLOCK() );
	}
	else {
		$sock->blocking(0);
	}
}

# ------------------------------------------------------------------------------
# routine: set_blocking
# ------------------------------------------------------------------------------
sub set_blocking {

	my $sock = shift;
	if ($blocking_supported) {
		my $flags = fcntl( $sock, F_GETFL(), 0 );
		$flags &= ~O_NONBLOCK();    # Clear blocking, but preserve others
		fcntl( $sock, F_SETFL(), $flags );
	}
	else {
		$sock->blocking(1);
	}
}

# ------------------------------------------------------------------------------
# routine: wait_for
#
# Wait for a user event. Does not wait when the user event has already been 
# signaled.
#
# Parameters:
# $event - (string) name of the user event
# $timeout - (number not necessarly an integer) optional time out in seconds
#
# Returns:
# undef when unblocked by the timeout or the user event name or data 
# ------------------------------------------------------------------------------
sub wait_for {
	my ($event, $timeout) = @_;
	
	$log->info("wait_for ($event, $timeout)");
	my $start = time();
	
	while (!(exists($pendings->{$event}))) {
	   eventLoop (0.1);
	   if ($timeout) {
	       if ((time() - $start) > $timeout ) {
	       	   $log->info("wait_for unblocked on timeout");
	           return undef;
	       }
	   }
	}
	my $data = shift (@{$pendings->{$event}});
	unless (@{$pendings->{$event}}) {
	    delete ($pendings->{$event});
	}
	$log->info("wait_for unblocked on event $event");
	$log->debug("data=$data");
	return $data;
}

# ------------------------------------------------------------------------------
# routine: signal
#
# Signal a user event, designed to be called from an event handler 
#
# Parameters:
# $event - (string) name of the user event
# $data - data to return to wait_for
#
# TODO: management of a queue of events, a unique event is not adapted to networking
# ------------------------------------------------------------------------------
sub signal {
	my ($event, $data) = @_;
	
	$log->info("signal($event)");

    unless(defined($data)) {
        $data = $event;
    }
    	
	unless (exists($pendings->{$event})) {
	    $pendings->{$event} = [$data];
	} else {
	   push (@{$pendings->{$event}}, $data);
	}

}

1;
