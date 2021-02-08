# ------------------------------------------------------------------------
# Title:  Emulated Blocking TCP/IP Client Template
#
# Source - <file:../ebclient.pl.html>
#
# Abstract:
#
#    Client for the Fibonacci server. This client emulates blocking IOs
#    with non blocking ones.
#    It uses the simplicity of APIs of blocking IOs while performing Event
#    loop processing for non blocking objects.
#
#    The access to the server is almost as simple than for the blocking
#    client.
#
#    This template checks the received values. The -fail option
#    of the ServerTemplate can be used to generates random
#    errors.
# 
# Usage:
# (Start code)
# Emulated blocking TCP/IP Client template.
#
# This script is a simple example of TCP/IP client that you can
# customize to your needs. By default, it send requests to the Fibonnacci server.
#
# This version use the emulated blocking IOs API, which is as simple than the blocking
# IOs API but processes the event loop for non blocking connectors.
#
# usage: perl ebclient.pl [options]
#        -verbose         flag    switch on verbose mode.
#        -min             string  First value
#        -match           array   Keywords, execute the matching parts, (default all)
#        -max             string  max value
#        -requirements    array   Requirements covered by the test
#        -directory       string  Logs and result directory
#        -outputDirectory string  directory for outputs
#        -host            array   list of host:port. ":port" accepted for localhost
#        -memory          flag    checks the memory usage.
#        -synopsis        string  test short description
#        -skip            array   Keyword, skip the matching parts (default none)
#        -pid             string  pid of the process to monitor
#        -iteration       string  number of test iteration.
#        -help            flag    display the online help.
#        -testId          string  test identificator. (default = script basename)
#        -performance     flag    displays execution time.
#
# Examples:
#    to run the script as a Fibonnaci client on localhost, port 2345:
#    perl ebclient.pl -host :2345
#    
#    to start multiple clients
#    perl ebclient.pl -host :2345 -host :2346 -host :2347
#
# (end)
# ------------------------------------------------------------------------
package EmulatedBlockingClientTemplate;

use strict;
use 5.010;
use warnings;
use lib "$ENV{'FTF'}/lib";
use lib "$ENV{'FTF'}/templates";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Test;

$VERSION = 1;
@ISA     = qw(Test);

use Data::Dumper;
use ExecutionContext;
use ScriptConfiguration;

# use Network::Client;
use Events::Socket;
use CODECs::Telnet;

my $defaultPort = 1234;

# ########################################################################

# ------------------------------------------------------------------------
# routine: fibo
#
# Compute the Fibonnaci value. Around 2 sec for fibo(30)
#
# ------------------------------------------------------------------------
sub fibo {
    my $n = shift;

    if ( ( $n == 0 ) || ( $n == 1 ) ) {
        return 1;
    }
    else {
        return fibo( $n - 1 ) + fibo( $n - 2 );
    }
}

# ------------------------------------------------------------------------
# routine: call
#
# call a server and send some Finonacci requests
#
# Parameters:
#    $host - server hostname
#    $port - server port
#    $nb   - number of request to send
#    $coef - used to compute the input parameter from the index
# ------------------------------------------------------------------------
sub call {
    my ( $Self, $host, $port, $min, $max ) = @_;

    $Self->info("connecting to $host:$port\n");

    my $codec = new CODECs::Telnet;

    my $server = new Events::Socket (
        codec    => $codec,
        emulate_blocking => 1);
    $server->connect($host, $port, 'tcp');

    for ( my $i = $min ; $i <= $max ; $i++ ) {

        $server->send( $i . "\n" );
        my $msg = $server->receive();

        my $expected = fibo($i);
        chomp($msg);
        my $fibo;
        if ( $msg =~ /fibo \(\d+\) = (\d+)/ ) {
            $fibo = $1;
        }
        $Self->ok( $fibo eq $expected,
            "server Fibonacci ($i) = $expected, received \"$fibo\"" );

        say("remote fib($i) = $fibo");
    }

    $server->close();
}

# ------------------------------------------------------------------------
# routine: run
#
#  Scrip main method.
# ------------------------------------------------------------------------
sub TestMain {
    my $Self = shift;

    my @hosts = defined($Self->{'config'}->value('host'))
        ? @{ $Self->{'config'}->value('host') }
        : ();
    my $min  = $Self->{'config'}->value('min');
    my $max  = $Self->{'config'}->value('max');

    # creates a client for each CLI host:port parameter
    foreach my $host (@hosts) {
    	
        if ( $host =~ /(.*):(\d*)/ ) {
            my $hostid = $1 ? $1 : "localhost";
            my $port   = $2 ? $2 : $defaultPort;

            $Self->call( $hostid, $port, $min, $max );
        }
        else {
            die "bad host:port ($host)";
        }
    }
}

# ------------------------------------------------------------------------
# On line help and options.
my $help_header = 'Emulated blocking TCP/IP Client template.

This script is a simple example of TCP/IP client that you can
customize to your needs. By default, it send requests to the Fibonnacci server.

This version use the emulated blocking IOs API, which is as simple than the blocking
IOs API but processes the event loop for non blocking connectors.

usage: perl ebclient.pl [options]';

my $help_footer = "
Examples:
    to run the script as a Fibonnaci client on localhost, port 2345:
    perl ebclient.pl -host :2345
    
    to start multiple clients
    perl ebclient.pl -host :2345 -host :2346 -host :2347
";

# If you specify a configuration file, it must exist.
my $config = new ScriptConfiguration(
    'header'     => $help_header,
    'footer'     => $help_footer,
    'scheme'     => TEST,
    'parameters' => {
        host => {
            type        => "array",
            description => "list of host:port. \":port\" accepted for localhost",
            default => ["localhost:54321"]
        },
        min => {
            type        => "string",
            description => "First value",
            default     => "1"
        },
        max => {
            type        => "string",
            description => "max value",
            default     => "30"
        },
    },
    #    'configFile' => $configFile
);

# To customize: replace by your package name
my $script = new EmulatedBlockingClientTemplate(
    testId       => $config->value('testId'),
    synopsis     => $config->value( "synopsis" ),
    config       => $config,
    loggerName   => "Test",
    iteration    => $config->value('iteration'),
    match        => $config->value('match'),
    skip         => $config->value('skip'),
    memory       => $config->value('memory'),
    pid          => $config->value('pid'),
    performance  => $config->value('performance')
);
$script->run();
