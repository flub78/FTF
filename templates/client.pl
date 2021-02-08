# ------------------------------------------------------------------------
# Title:  TCP/IP Client Template
#
# Source - <file:../client.pl.html>
#
# Abstract:
#
#    This script is a TCP/IP client template that uses the Events module.
#    It is a non blocking client, which means that you can declare
#    as many clients and servers that you want in the same script
#    and have them scheduled by the same event loop.
#
#    In simple cases if you only have one client which can
#    perform blocking operations without blocking others servers
#    and clients it is simpler to use the <BlockingClientTemplate.pl>
#
#    The script is generic, all the actions specific to the kind of
#    requests and reaction to replies are handled into the
#    <FiboSequence> class. You can generate another client
#    just by replacing this class.
#
#    This template is not the simplest one of the toolkit, I have made it really
#    close of a real life test. It is non-blocking and you should be able to use it
#    to test several servers at the same time.
#
# Usage:
# (Start code)
# Client template.
#
# This script is an example of TCP/IP client that you can
# customize to your needs. By default, it send requests to the Fibonnacci server.
#
# usage: perl client.pl [options]
#        -verbose         flag    switch on verbose mode.
#        -block_size      string  block size for sending
#        -match           array   Keywords, execute the matching parts, (default all)
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
#    perl client.pl -host :2345
#
#    to start multiple clients
#    perl client.pl -host :2345 -host :2346 -host :2347
# (end)
#
# Logger:
#
# Use the "Test" logger to control the verbosity level of this script.
# (Start code)
# log4perl.logger.Test = ALL, Console
# (end)
# ------------------------------------------------------------------------
package ClientTemplate;

use strict;
use lib "$ENV{'FTF'}/lib";
use lib "$ENV{'FTF'}/templates";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Test;
use Carp;

$VERSION = 1;
@ISA     = qw(Test);

use Data::Dumper;
use ExecutionContext;
use ScriptConfiguration;

use Events::Server;
use Events::ClientSequencer;
use FiboSequence;
use Events::EventsManager qw(eventLoop stopLoop after);
use CODECs::Telnet;

my $defaultPort = 54321;

# ------------------------------------------------------------------------
# method: SetUp
#
# Test preparation, empty when nothing to do. Can be skipped if the
# test context can be setup for several test executions.
# ------------------------------------------------------------------------
sub SetUp {
    my $Self = shift;

    $Self->trace("SetUp");
    $Self->{success}  = 0;
    $Self->{failures} = 0;

    $Self->{'transaction_number'} = 0;
    $Self->{'window'}             = 0;
    $Self->{'messages_sent'}      = 0;
    $Self->{'messages_received'}  = 0;
    $Self->{'errors'}             = 0;
    $Self->{'total_time'}         = 0;
    $Self->{'max_time'}           = 0;
    $Self->{'min_time'}           = 1000000000;
}

# ------------------------------------------------------------------------
# routine: run
#
#  Scrip main method.
# ------------------------------------------------------------------------
sub TestMain {
    my $Self = shift;

    my @hosts      = @{ $Self->{'config'}->value('host') };
    my $block_size = $Self->{'config'}->value('block_size');

    my $codec = new CODECs::Telnet();

    # creates a client for each CLI host:port parameter
    foreach my $host (@hosts) {
        if ( $host =~ /(.*):(\d*)/ ) {
            my $hostid = $1 ? $1 : "localhost";
            my $port   = $2 ? $2 : $defaultPort;

            # service definition
            # To customize, replace by your own sequence
            my $min = 10;
            my $max = 20;
            my $nb  = $max - $min + 1;
            my $seq = new FiboSequence(
                window => 4,
                number => $nb,
                min    => $min,
                test   => $Self
            );

            my $client = new Events::ClientSequencer(
                loggerName => $Self->{'loggerName'},
                codec      => $codec,
                block_size => $block_size,
                sequence   => $seq,
                test       => $Self
            );
            die "Cannot create client. Reason: $!\n" unless $client;

            $client->connect( $hostid, $port );
        }
        else {
            die "bad host:port ($host)";
        }
    }
    eventLoop();
}

# ------------------------------------------------------------------------
# method: CleanUp
#
# Test cleanup, for example delete all the test generated files.
# ------------------------------------------------------------------------
sub CleanUp {
    my $Self = shift;

    $Self->trace("CleanUp");

    my $n = $Self->{'transaction_number'};
    $Self->logScalarCounter( "Transactions = " . $n );

    $Self->logScalarCounter( "Window = " . $Self->{'window'} / $n ) if ($n);
    $Self->logScalarCounter( "Messages sent = " . $Self->{'messages_sent'} );
    $Self->logScalarCounter(
        "Messages received = " . $Self->{'messages_received'} );
    $Self->logScalarCounter( "Errors = " . $Self->{'errors'} );
    $Self->logScalarCounter( "Total service time = " . $Self->{'total_time'} );
    $Self->logScalarCounter(
        "Average service time = " . $Self->{'total_time'} / $n )
      if ($n);
    $Self->logScalarCounter( "Minimal service time = " . $Self->{'min_time'} )
      if ( $Self->{'min_time'} );
    $Self->logScalarCounter( "Maximal service time = " . $Self->{'max_time'} )
      if ( $Self->{'max_time'} );

    if ( $Self->{failures} == 0 ) {
        $Self->warn(
"PASSED global $Self->{testId}, success=$Self->{success}, failures=0",
            ".Checks"
        );
    }
    else {
        $Self->error(
"FAILED global $Self->{testId}, success=$Self->{success}, failures=$Self->{'failures'}",
            ".Checks"
        );
        $Self->error(
            "FAILED because $Self->{testId} $Self->{'failuresReasons'}",
            ".Checks" );
    }
}

# ------------------------------------------------------------------------
# On line help and options.
my $help_header = 'TCP/IP Client template.

This script is an example of TCP/IP client that you can
customize to your needs. By default, it send requests to the Fibonnacci server. It is based on the events management so you can connect to
several servers at the same time.

usage: perl client.pl [options]';

my $help_footer = "
Examples:
    to run the script as a Fibonnaci client on localhost, port 2345:
    perl client.pl -host :2345
    
    to start multiple clients
    perl client.pl -host :2345 -host :2346 -host :2347
";

# If you specify a configuration file, it must exist.
#my $configFile = ExecutionContext::configFile();
my $config     = new ScriptConfiguration(
    'header'     => $help_header,
    'footer'     => $help_footer,
    'scheme'     => TEST,
    'parameters' => {
        host => {
            type        => "array",
            description => "list of host:port. \":port\" accepted for localhost",
            default => ["localhost:54321"]
        },
        block_size => {
            type        => "string",
            description => "block size for sending",
            default     => 0
        },
    },
#    'configFile' => $configFile
);

($config->value('host')) or croak "missing host parameter";

# To customize: replace by your package name
my $script = new ClientTemplate(
    testId   => $config->value('testId'),
    synopsis => $config->value(
        "synopsis"
    ),
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
