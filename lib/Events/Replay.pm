# ----------------------------------------------------------------------------
#
# Title: Class Events::Replay
#
# File - EventsReplay.pm
# Author - frederic
#
# Name:
#
#    package Events::Replay
#
# Abstract:
#
#    Replay connector. This class replays a file produced by the spy tool in
#    recording mode. 
#
#    Only lines that match the role string are replayed (127.0.0.1:48023). That
#    way it is possible to selectively replay one role from a recording containing
#    several connections. 
#
# Scenario file format:
# (Start code)
# 2009/08/05 09:39:53 DEBUG Events.ProxyService:46 Creating instance of Events::ProxyService
# 2009/08/05 09:39:53 DEBUG Events.ProxyService:164 <- (127.0.0.1:48023) 300a
# 2009/08/05 09:39:53 DEBUG Events.ProxyService:205 -> (127.0.0.1:48023) 310a
# 2009/08/05 09:39:53 DEBUG Events.ProxyService:164 <- (127.0.0.1:48023) 310a
# 2009/08/05 09:39:53 DEBUG Events.ProxyService:205 -> (127.0.0.1:48023) 310a
# 2009/08/05 09:39:53 DEBUG Events.ProxyService:164 <- (127.0.0.1:48023) 320a
# 2009/08/05 09:39:53 DEBUG Events.ProxyService:205 -> (127.0.0.1:48023) 320a
# 2009/08/05 09:39:53 DEBUG Events.ProxyService:164 <- (127.0.0.1:48023) 330a
# 2009/08/05 09:39:53 DEBUG Events.ProxyService:205 -> (127.0.0.1:48023) 330a
# 2009/08/05 09:39:53 DEBUG Events.ProxyService:164 <- (127.0.0.1:48023) 340a
# 2009/08/05 09:39:53 DEBUG Events.ProxyService:205 -> (127.0.0.1:48023) 350a
# 2009/08/05 09:39:53 DEBUG Events.ProxyService:99 (127.0.0.1:48023) connection closed
# (end)
# ----------------------------------------------------------------------------
package Events::Replay;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Log::Log4perl;
use Data::Dumper;
use Events::Connector;
use Events::EventsManager qw(eventLoop stopLoop after);
use Events::Socket;
use Time::Local;

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
    
    # Create a new internet socket
    my $fd;
    open ($fd, $mode . $name) or die ("cannot open file $name!");
    $Self->{socket} = $fd;
   ($Self->{socket}) or die "open of $name failed";
   
    if ($mode eq "<") {   
        Events::EventsManager::registerHandler( $Self, $Self->{socket}, 'read' );
    }
    
#    print "Openning scenario\n";
#    print "mode = ", $Self->{'mode'}, "\n";    
#    print "role = ", $Self->{'role'}, "\n";    
#    print "host = ", $Self->{'host'}, "\n";    
#    print "port = ", $Self->{'port'}, "\n";  
    
    ($Self->{'mode'} eq 'client') or die "server replay not yet supported"; 
    $Self->{'client'} = new Events::Socket();
    $Self->{'client'}->connect($Self->{'host'}, $Self->{'port'});  
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

	my $role = $Self->{'role'};

	# skip lines at bat criticity level
	return unless ($msg =~ /DEBUG/);
	# skip lines for other connections
	return unless ($msg =~ /\($role\) (.*)/);
	my $data = $1;
	
	# skip lines without date
	return unless ($msg =~ /((\d+)\/(\d+)\/(\d+)\s+(\d+)\:(\d+)\:(\d+)(\.\d+)*)/);
	my $date = $1;
	my ($year, $month, $day, $hour, $minute, $sec) = ($2, $3, $4, $5, $6, $7);
	# ($year, $month, $day, $hour, $minute, $sec) = 
	# (2009, 7, 6, 11, 4, 0);
		
	# usually log files are in local time (perhaps not a good idea)
	my $fileTime = timelocal($sec, $minute, $hour, $day, $month - 1, $year);
	
	# We want to schedule the replay at the same rate than the initial 
	# recording 
	
	# It means that if the replay time is ahead of the recording
	# time scale we have to suspend the current handler.
	# it is not supported yet by Events, doing that would prevent
	# transmission so just play everything possible until the feature
	# is supported.
	
	# time 0
	unless (exists($Self->{'scenarioStartTime'})) {
		$Self->{'scenarioStartTime'} = $fileTime;
		$Self->{'startTime'} = time;
	}
	my $scenarioTime = $fileTime - $Self->{'scenarioStartTime'};
	my $replayTime = time - $Self->{'startTime'};

	# determine the line type
	my $action;
	if ($msg =~ /<-/) {
		$action = "sending $data";
		$Self->{'client'}->send(pack ("H*", $data));
	} elsif ($msg =~ /->/) {
		$action = "reception $data";
	} elsif ($msg =~ /connection close/) {
		$action = 'close';
	}
	 
	print "date=$date, action=$action, data=$data\n";
#	print "$year/$month/$day $hour:$minute:$sec\n";
#	print "time = ", time, "\n";
#	print "file time = ", $fileTime, "\n";
#	print "diff = ", time - $fileTime, "\n";
#
#	print "scenario time = ", $scenarioTime, "\n";
#	print "replay time = ", $replayTime, "\n";
	
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

	after( 3, \&stopLoop );
}

1;
