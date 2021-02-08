# ----------------------------------------------------------------------------
#
# Title: Class Events::Server
#
# File - Events/Server.pm
# Author - frederic
#
# Name:
#
#    package Events::Server
#
# Abstract:
#
#    TCP/IP servers with an object interface
#
# ----------------------------------------------------------------------------
package Events::Server;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Exporter;
use Log::Log4perl;
use IO::Socket;    # more convenient than Socket
use Events::EventsManager;
use ClassWithLogger;
use Carp;

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

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    # Others initialisation
    exists($Self->{port}) or croak "undefined port";
    exists($Self->{factory}) or croak "Server require a package name to handle client connection (factory)";

    $Self->trace("Server on port $Self->{'port'}");
    $Self->{'accepted'} = 0;
    
    # total for all connections
    $Self->{'bytesReceived'}    = 0;
    $Self->{'bytesSent'}        = 0;
    $Self->{'messagesReceived'} = 0;
    $Self->{'messagesSent'}     = 0;
    
    $Self->start();
    #Events::EventsManager::registerTimer ($Self, 5, 100);    
}

# ----------------------------------------------------------------------------
# method: data_received
#
#    Callback activated when a new client connect to the server.
# ----------------------------------------------------------------------------
sub data_received {
    
    my ($Self, $sock) = @_;
    
    $Self->trace("Server data_received $sock");
    
    my $new_sock = $sock->accept();

    my $params;
    if (exists($Self->{'params'})) {
        $params = ", $Self->{'params'}";
    } else {
        $params = "";
    }
    
    my $cmd = "
       require $Self->{'factory'};
       my \$connection = new $Self->{'factory'} (socket => \$new_sock $params);
    ";
    $Self->trace("eval $cmd");
    my $res = eval $cmd;
    unless ($res) {
        croak "Eval error: $@";
    } 

    $res->{'codec'} = $Self->{'codec'};
     
    # clients are registered, check out is based on client cooperation
    # they have to unregister themself by calling signal
    $res->{'parent'} = $Self;
        
    $Self->{'accepted'} = $Self->{'accepted'} + 1;
    $Self->{'connections'}->{$res} = $Self->{'accepted'};
}

# ----------------------------------------------------------------------------
# method: signal
#
#    Method used by accepted connections during close to check out
# ----------------------------------------------------------------------------
sub signal {
    my ($Self, $connector) = @_;
    
    $Self->trace("signal $connector");
    
    $Self->{'bytesReceived'}    += $connector->bytesReceived();
    $Self->{'bytesSent'}        += $connector->bytesWritten();
    $Self->{'messagesReceived'} += $connector->messagesReceivedNumber();
    $Self->{'messagesSent'}     += $connector->messagesReceivedNumber();
    delete ($Self->{'connections'}->{$connector});
}

# ----------------------------------------------------------------------------
# method: stop
#
#    Stop to  accept connections. Close the existing ones.
# ----------------------------------------------------------------------------
sub stop {
    my ($Self) = @_;
    
    close ($Self->{socket});
    Events::EventsManager::removeHandler($Self, 'write');
}

# ----------------------------------------------------------------------------
# method: start
#
#    Start or restart the server.
# ----------------------------------------------------------------------------
sub start {
    my ($Self) = @_;
    $Self->{socket} = new IO::Socket::INET(
            LocalHost => 'localhost',
            LocalPort => $Self->{port},
            Proto     => 'tcp',
            Listen    => 5,
            Reuse     => 1,
        );
    my $port = $Self->{'port'};    
    croak "Could not listen on port port $port: $!" unless $Self->{socket};   
    Events::EventsManager::registerHandler($Self, $Self->{socket}, 'read');    
}

# ----------------------------------------------------------------------------
# method: send
#
#    Send a message to all connected clients.
# ----------------------------------------------------------------------------
sub send {
    my ($Self, $msg) = @_;

    foreach my $key (keys(%{$Self->{'connections'}})) {
        $key->send($msg);
    }   
}

# ----------------------------------------------------------------------------
# method: timeout
#
#    Callback called when the timeout expires.
# ----------------------------------------------------------------------------
sub timeout {
    my ($Self) = @_;
    
    print $Self->status(), "\n";
}

# ----------------------------------------------------------------------------
# method: status
#
#    Return a string containing the server status
# ----------------------------------------------------------------------------
sub status {
    my ($Self, $msg) = @_;

    my $str = "";
    $str .= "Number of accepted clients   = " . $Self->{'accepted'} . "\n";
    $str .= "Number of active connections = " . scalar(keys(%{$Self->{'connections'}})) . "\n";
    $str .= "Server received bytes        = " . $Self->{'bytesReceived'} . "\n";
    $str .= "Server sent bytes            = " . $Self->{'bytesSent'} . "\n";
    $str .= "Server messages received     = " . $Self->{'messagesReceived'} . "\n";
    $str .= "Server messages sent         = " . $Self->{'messagesSent'} . "\n";
    
    return $str;
    foreach my $key (keys(%{$Self->{'connections'}})) {
        $str .= "client key = $key $Self->{'connections'}->{$key}\n";
        $str .= "\tbytes received = " . $key->bytesReceived() . "\n";
        $str .= "\tbytes sent     = " . $key->bytesWritten() . "\n";
        $str .= "\tmsg received   = " . $key->messagesReceivedNumber() . "\n";
        $str .= "\tmsg sent       = " . $key->messagesSentNumber() . "\n";
    }
    return $str;   
}
1;
