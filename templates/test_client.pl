#!/usr/bin/perl -w

# ------------------------------------------------------------------------
# Title: Simple TCP/IP test client template
#
# Source - <file:../poe_client.pl.html>
#
# Abstract:
#
#    Example of TCP/IP test client using POE (Perl Object Environment).
#    This script connects to a TCP/IP server and test the behavior
#    of the server.
# ------------------------------------------------------------------------
use strict;
use 5.010;

use Getopt::Long;
use Log::Log4perl qw(:easy);
use lib "$ENV{'FTF'}/lib";
use POE;
use POE qw(
  Component::Client::TCP
  Filter::Reference
  Filter::Binary);
use MTest;

# Script name
my $name = $0;
Log::Log4perl::init("$ENV{'FTF'}/conf/log4perl.conf");
my $log = Log::Log4perl->get_logger('Network');    # log4perl.logger.script

my $host = "localhost";
my $port = 1234;

# options declaration
my $help    = 0;
my $verbose = 0;
my @hosts   = ("$host:$port");                     # The host to test.
my $binary  = "";

my $iteration = 1;
my $fail;
my $testId = "test_1";
my $scenario = $testId;
my @match = ();
my @skyp = ();
my $memory;
my $performance;


# others global variables
my $options = {
    'help'     => \$help,
    'verbose!' => \$verbose,
    'binary'   => \$binary,
    'host=s'   => \@hosts,
    "iteration=i" => \$iteration,
    "fail"        => \$fail,
    "testId=s"    => \$testId,
    "scenario=s"  => \$scenario,
    "memory"      => \$memory,
    "performance" => \$performance,
    "match=s"     => \@match,
    "skyp=s"      => \@skyp
};

# ------------------------------------------------------------------------
# routine: usage
# ------------------------------------------------------------------------
sub usage () {
    say "
TCP/IP client template. 

usage: perl $name [options]

     Options:
       -help            brief help message
       -verbose         switch on verbose mode
       -binary          binary mode instead of telnet mode
       -host host:port  host and port to connect to (\":port\" accepted for localhost)
       -iteration n     number of iteration for the test (default=1)
       -fail            emulate a failed test
       -id name         test id (default=test_1)
       -scenario name   name of the scenario to execute (default = \"\")
       -memory          activate memory leaks checks
       -performance     measure the time for each iteration
        
Exemple:

    to run the script as a Fibonnaci client on localhost, port 54321:
    perl $name -host :54321
    
    to start multiple clients
    perl $name -host :2345 -host :2346 -host :2347
";
    exit();
}

# log invocation command
$log->info( $0 . " " . join( " ", @ARGV ) );

# parse the CLI
GetOptions( %{$options} );
if ($help) {
    # print usage and exit
    usage();
}

my $test = new MTest(testId => $testId, 
    scenario => $scenario,
    logName => "Test",
    synopsis => "TCP/IP server test",
    junit => $scenario . ".xml");

my $filter = ($binary) ? POE::Filter::Binary->new() : POE::Filter::Line->new();
foreach my $hostport (@hosts) {
    if ( $hostport =~ /(.*):(\d*)/ ) {
        $host = $1;
        $port = $2;
    }

    POE::Component::Client::TCP->new(
        RemoteAddress => $host,
        RemotePort    => $port,
        Filter        => $filter,
        Connected     => \&connected_cb,
        ConnectError  => \&connectedError_cb,
        ServerInput   => \&serverInput_cb,
    );
}
$poe_kernel->run();
exit 0;

# ------------------------------------------------------------------------
# method: SetUp
#
# Test preparation, empty when nothing to do. Can be skipped if the
# test context can be setup for several test executions.
# ------------------------------------------------------------------------
sub SetUp {
    $test->start();
    $test->iteration_start();
}

# ------------------------------------------------------------------------
# method: CleanUp
#
# Test cleanup, for example delete all the test generated files.
# ------------------------------------------------------------------------
sub CleanUp {
    $test->iteration_stop();
    $test->stop();
}

# ------------------------------------------------------------------------
# routine: connected_cb
#
# Callback invoked on connection
# ------------------------------------------------------------------------
sub connected_cb {
    $log->info("connected to $host:$port ...");

    # run the test
    SetUp();
    
    $_[HEAP]->{count} = 0;
    $_[HEAP]->{server}->put("Hello world");
}

# ------------------------------------------------------------------------
# routine: connectedError_cb
# 
# Callback invoked on connection error
# ------------------------------------------------------------------------
sub connectedError_cb {
    $log->error("could not connect to $host:$port ...");
    $test->ok( 0, "Network error" );
}

# ------------------------------------------------------------------------
# routine: serverInput_cb
#
# when the server answer the question
# ------------------------------------------------------------------------
sub serverInput_cb {
  
    my ( $kernel, $heap, $input ) = @_[ KERNEL, HEAP, ARG0 ];

    $test->iteration_stop();
    $log->info("<- $host:$port: $input");
    $_[HEAP]->{count}++;
    my $count = $_[HEAP]->{count};
    if ( $_[HEAP]->{count} < $iteration ) {
        $test->ok( 1, "server reply" );
        $test->ok(($input == $count - 1) , "expected reply: " . ($count - 1) . "==" . $input );
        
        # next request
        my $cnt = $_[HEAP]->{count};
        $test->iteration_start();
        $_[HEAP]->{server}->put( $_[HEAP]->{count} );
    }
    else {
        CleanUp();
        $test->result();
        exit;
    }
}

# ------------------------------------------------------------------------
# routine: logFilename
#
# This routine is used in the log4perl configuration file
# It must stay in the global name space. If this version does not
# work for you just call it with the name you want.
#
# Return:
#     - The log file name.
# ------------------------------------------------------------------------
sub logFilename {
    return $0 . ".log";
}

1;
