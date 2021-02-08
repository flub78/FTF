# ------------------------------------------------------------------------
# Title:  Spy TCP/IP proxy
#
# Abstract:
#
#    TCP/IP connection recorder. This program is a proxy able to
#    record all data exchanged between the client and the server.
#
#    There is no special support for data recording. As all clients and
#    and servers using the Handles module, it uses log4Perl loggers
#    to record all sent and received data at DEBUG level for hexadecimal
#    data and at INFO level for high level messages.
#
#    In your log4perl.conf:
#
#    (Start code)
#    log4perl.logger.Handles.Network = DEBUG, Console, LogFile
#    (end)
#
# Usage:
#
# (Start code)
# usage: perl spy.pl [options]
#
#        -verbose         flag,     switch on verbose mode.
#        -outputDirectory string,   directory for outputs
#        -port            string,   port listened for clients
#        -host            string,   server address. ":port" accepted for localhost
#        -client          flag,     only in replay mode, replay as a client
#        -help            flag,     display the online help.
#        -server          flag,     only in replay mode, replay as a server
#        -role            string,   identifier of the partner to replay (host:port)
#        -replay          string,   name of the scenario file to replay
# (end)
#
# Example:
#
# To record the connection between a server on localhost, port 2345 and accept
# clients on port 2346 then to replay the role of the client.
#
# (Start code)
# perl spy.pl -host :2345 -port 2346
# grep DEBUG spy.log > scen1.txt
# perl spy.pl -host :2345 -replay scen1.txt -client -role 127.0.0.1:48150
# (end)
#
# Example of a recorded connection:
#
# I have just filtered log lines at the DEBUG level to get only the traces
# of the exchanged data.
#
# (Start code)
# 2009/08/05 09:39:53 DEBUG Handles.ProxyService:46 Creating instance of Events::ProxyService
# 2009/08/05 09:39:53 DEBUG Handles.ProxyService:164 <- (127.0.0.1:48023) 300a
# 2009/08/05 09:39:53 DEBUG Handles.ProxyService:205 -> (127.0.0.1:48023) 310a
# 2009/08/05 09:39:53 DEBUG Handles.ProxyService:164 <- (127.0.0.1:48023) 310a
# 2009/08/05 09:39:53 DEBUG Handles.ProxyService:205 -> (127.0.0.1:48023) 310a
# 2009/08/05 09:39:53 DEBUG Handles.ProxyService:164 <- (127.0.0.1:48023) 320a
# 2009/08/05 09:39:53 DEBUG Handles.ProxyService:99 (127.0.0.1:48023) connection closed
# (end)
# ------------------------------------------------------------------------
package Spy;

use strict;
use lib "$ENV{'FTF'}/lib";

use Script;
use IO::Socket;
use ScriptConfiguration;

use Events::EventsManager qw(eventLoop stopLoop after);
use Events::Server;

# use Events::Replay;
# use Events::ScenarioDumper;
use CODECs::Telnet;

use Event::RPC::Server;
use Event::RPC::Logger;

use vars qw($VERSION @ISA @EXPORT);
use Exporter;

$VERSION = 1;
@ISA     = qw(Script);

my $help_header = '
Spy is a TCP/IP connection player/recorder. It can act like
a proxy between a server and a client and record the transmited data.

To record the data into a file, the network logger must be set at least
at the DEBUG level in the log4perl.conf file:
log4perl.logger.Handles.Network = DEBUG, Console, LogFile

usage: perl spy.pl [options]
';

my $help_footer = '
Examples:

    To record a connection between a client and a server
    perl spy.pl -host :2345 -port 2346
    
    to replay the client part
    perl spy.pl -host :2345 -replay scen1.txt -client -role 127.0.0.1:48150
    
    to dump a scenario with a codec
    perl spy.pl -dump km-ecs.scen -codec CODECs::KM_ECS \
        -role "127.0.0.1:2345"
';

my $config = new ScriptConfiguration(
	'header'     => $help_header,
	'footer'     => $help_footer,
	'scheme'     => SCRIPT,
	'parameters' => {
		host => {
			type        => "string",
			description => "server address. \":port\" accepted for localhost"
		},
		port => {
			type        => "string",
			description => "port listened for clients"
		},
		replay => {
			type        => "string",
			description => "name of the scenario file to replay"
		},
		dump => {
			type        => "string",
			description => "scenario file, dump a role according to a codec"
		},
		codec => {
			type => "string",
			description =>
			  "Codec class for high level traces, ex -codec CODECs::Binary"
		},
		role => {
			type        => "string",
			description => "identifier of the partner to replay (host:port)"
		},
		client => {
			type        => "flag",
			description => "only in replay mode, replay as a client"
		},
		server => {
			type        => "flag",
			description => "only in replay mode, replay as a server"
		}
	},
);

my $defaultPort = 1234;
my $server;

sub status { return $server->status(); }

# ########################################################################
sub rpcServer {
	my $Self = shift;

	my %ssl_args;
	my %auth_args;

	#-- Create a Server instance and declare the
	#-- exported interface
	my $server = Event::RPC::Server->new(
		name    => "test daemon",
		port    => 5555,
		classes => {
			'Spy' => {
				status   => '_constructor',
				set_data => 1,
				get_data => 1,
				hello    => 1,
				quit     => 1,
			},
		},
	);

	# $server->start();
	$server->setup_listeners();
	print "server started\n";
}

# ------------------------------------------------------------------------
# routine: run
#
#  Scrip main method.
# ------------------------------------------------------------------------
sub run {
	my $Self = shift;

	# Command line parameters analysis
	my $host         = $config->value('host');
	my $listenedPort = $config->value('port');
	my $replay       = $config->value('replay');

	my $role      = $config->value('role');
	my $client    = $config->value('client');
	my $server    = $config->value('server');
	my $codecName = $config->value('codec');
	my $dump      = $config->value('dump');
	my $verbose   = $config->value('verbose');

	my $mode;

	# Check options validity
	if ( defined($replay) ) {
		if ( defined($client) ) {
			!defined($server) or die "-client and -server option are exclusive";
			$mode = 'client';
		}
		else {
			defined($server)
			  or die "you must specify -client or -server in replay mode";
			$mode = 'server';
		}
		defined($role) or die "-role is mandatory in replay mode";
	}

	# extract host and port
	my $hostid;
	my $port;
	unless ($dump) {

		# set the server parameters
		unless ( $host =~ /(.*):(\d*)/ ) {
			die "bad host:port ($host)";
		}
		$hostid = $1 ? $1 : "localhost";
		$port   = $2 ? $2 : $defaultPort;
	}

	my $codec = CODECs::Telnet->instance( 'verbose' => $verbose );
	my $targetCodec = $codec;
	if ($codecName) {
		my $cmd = "
		   require $codecName;
		   my \$codec = $codecName->instance('verbose' => $verbose);
		";
		$targetCodec = eval $cmd;
		die "eval error: $@" unless ($targetCodec);
	}

	# start the services
	if ($replay) {

		# create and activate a replayer
		my $scenario = new Events::Replay(
			mode         => $mode,
			role         => $role,
			host         => $hostid,
			port         => $port,
			listenedPort => $listenedPort
		);
		$scenario->open( $replay, "<" );
	}
	elsif ($dump) {

		# create and activate a scenarioDumper
		my $scenario = new Events::ScenarioDumper(
			codec       => $codec,
			targetCodec => $targetCodec,
			role        => $role,
		);
		$scenario->open( $dump, "<" );

	}
	else {

		# create and activate a recorder
		my $server = new Events::Server(
			port    => $listenedPort,
			factory => 'Events::ProxyService',
			params  => "host => \'$hostid\', port => $port",
			codec   => $codec
		);
	}

	# start a remote procedure call server to be able to send commands
	# to the spy remotely
	$Self->rpcServer();

	eventLoop();
}

my $script = new Spy(
    config       => $config,
	loggerName => "Network",
);
$script->run();
