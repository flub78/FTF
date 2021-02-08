# ----------------------------------------------------------------------------
#
# Title: Class Events::ScenarioDumper
#
# File - EventsScenarioDumper.pm
# Author - frederic
#
# Name:
#
#    package Events::ScenarioDumper
#
# Abstract:
#
#    ScenarioDumper connector. This class dumps a file produced by the spy tool in
#    recording mode, according to a codec. 
#
#    Only lines that match the role string are dumped (127.0.0.1:48023). That
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
package Events::ScenarioDumper;

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

	$Self->{"scenario_in_buffer"} = "";
	$Self->{"scenario_out_buffer"} = "";
	    
    print "Openning scenario\n";
    print "role = ", $Self->{'role'}, "\n";        
}

# ----------------------------------------------------------------------------
# method: _process_data (private)
#
# Invoked for scenario line with data reception or sending
# ----------------------------------------------------------------------------
sub _process_data {
	my ($Self, $buffer_ref, $data, $str, $date) = @_;

	$$buffer_ref .= $data;
	
	my $len = $Self->{'targetCodec'}->message_length($$buffer_ref);
	return if ($len <= 0);

	while ($len > 0) {
		my $msg = CODECs::pop_message($buffer_ref, $len);
		my $decoded = $Self->{'targetCodec'}->decode($msg);
		my $img = $decoded->dump();
		print "\n$str $img\n\n";
		$len = $Self->{'targetCodec'}->message_length($$buffer_ref);
	}
}

# ----------------------------------------------------------------------------
# method: received_data
#
# Invoked for scenario line with data reception 
# ----------------------------------------------------------------------------
sub received_data {
	my ($Self, $data, $date) = @_;

	return $Self->_process_data(\$Self->{"scenario_in_buffer"}, $data, "->");
}


# ----------------------------------------------------------------------------
# method: sent_data
#
# Invoked for each scenario line with sent data
# ----------------------------------------------------------------------------
sub sent_data {
	my ($Self, $data, $date) = @_;

	return $Self->_process_data(\$Self->{"scenario_out_buffer"}, $data, "<-");
}

# ----------------------------------------------------------------------------
# method: messageReceived
#
#    Callback activated when a line has been read from the scenario.
#
#    Parameters:
#       $msg - binary buffer truncated to a full and unique application message
# ----------------------------------------------------------------------------
sub messageReceived {
	my ( $Self, $msg ) = @_;

	my $role = $Self->{'role'};

	# skip lines at bad criticity level
	return unless ($msg =~ /DEBUG/);
	# skip lines for other connections
	return unless ($msg =~ /\($role\)\s+(.*)/);
	my $data = $1;
	
	# skip lines without date
	return unless ($msg =~ /((\d+)\/(\d+)\/(\d+)\s+(\d+)\:(\d+)\:(\d+)(\.\d+)*)/);
	my $date = $1;
	my ($year, $month, $day, $hour, $minute, $sec) = ($2, $3, $4, $5, $6, $7);
	# ($year, $month, $day, $hour, $minute, $sec) = 
	# (2009, 7, 6, 11, 4, 0);
		
	# usually log files are in local time (perhaps not a good idea)
	my $fileTime = timelocal($sec, $minute, $hour, $day, $month - 1, $year);
	
	# determine the line type
	if ($msg =~ /<-/) {
		$Self->sent_data(pack("H*", $data), $date);
	} elsif ($msg =~ /->/) {
		$Self->received_data(pack("H*", $data), $date);
	} elsif ($msg =~ /connection close/) {
		# close
		print "connection closed\n";
	}
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

    stopLoop();
}

1;
