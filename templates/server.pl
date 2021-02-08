# ------------------------------------------------------------------------
# Title:  TCP/IP Server Template
#
# Source - <file:../server.pl.html>
#
# Abstract:
#
#    Server for the Fibonacci sequence. This example is interresting
#    because the service time can easily lasts a long time.
#
#    This script only analyses the configuration parameters and creates
#    servers. Servers have a configuration parameter named factory
#    which defines the class of the real service that will handle
#    each client connection. So to define another server you need
#    to define a new service and just pass its name to the server.
#
#    Except for the name of the launched servers, it is
#    completely generic. By setting the server_class and parameters
#    option you can even use it with your own server class. However, the
#    syntax is a little complicated, you shoud probably copy and edit
#    it to use the first syntax in a dedicated script.
#
# Usage:
#
# (Start code)
# usage: perl server.pl [options]
#        -verbose         flag,     switch on verbose mode.
#        -fail            flag,     when set, the server returns random errors
#        -async           flag,     when set, the server postpones the replies for a random duration
#        -block_size      string,   block size for sending
#        -outputDirectory string,   directory for outputs
#        -port            multiple, list of port to listen
#        -parameters      string,   parameters for the dynamic server
#        -server_class    string,   Server classs (default = Events::Server)
#        -help            flag,     display the online help.
#
# Examples:
#    to run the script as a Fibonnaci server on port 2345
#    perl server.pl -port 2345
#
#    to run it as an echo server, or any dynamically supplied class:
#    perl server.pl -port 2345 -server_class Events::Server \
#       -parameters "port => 2345, factory => 'Events::EchoService'"
#
#    to run multiple servers:
#    perl server.pl -port 2345 -port 2346 -port 2347
#
# (end)
#
# Have a look at the TCP/IP client template and blocking client template for compatible clients.
#
# Logger:
#
# Use the network logger to control the verbosity level of this script. File $FTF/conf/log4perl.conf.
#
# (Start code)
# log4perl.logger.Tests = ALL, Console
# (end)
# ------------------------------------------------------------------------
package ServerTemplate;

use strict;
use lib "$ENV{'FTF'}/lib";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Script;

$VERSION = 1;
@ISA     = qw(Script);

# To customize: add your own libraries
use Data::Dumper;
use ExecutionContext;
use ScriptConfiguration;

use Events::EventsManager qw(eventLoop stopLoop after);
use Events::Server;
use CODECs::Telnet;
use Carp;

# ------------------------------------------------------------------------
# routine: run
#
#  Scrip main method.
# ------------------------------------------------------------------------
sub run {
    my $Self = shift;

    my @servers      = @{ $Self->{'config'}->value('port') };
    my $server_class = $Self->{'config'}->value('server_class');
    my $parameters   = $Self->{'config'}->value('parameters');
    my $fail         = $Self->{'config'}->value('fail');
    my $async        = $Self->{'config'}->value('async');
    my $block_size   = $Self->{'config'}->value('block_size');

    # for flags to be 0, null string is not convenient in string interpretation
    $fail  = 0 unless ($fail);
    $async = 0 unless ($async);

    foreach my $port (@servers) {

        $Self->info("listening to $port");

        if ( !defined($server_class) || ( $server_class eq "" ) ) {

            # server class is not defined, dedicated script
            # You will be warn of missing classes at compile time
            # Use this syntax to adapt it to your own needs.
            my $codec  = new CODECs::Telnet();
            my $server = new Events::Server(
                port    => $port,
                factory => 'FiboService',
                params =>
"loggerName => \"Tests\", fail => $fail, async => $async, block_size => $block_size",
                codec => $codec,
            );

        }
        else {

            # type of service is defined dynamically
            # you will be warned of missing classes at run time.
            my $cmd = "
               require $server_class;
               my \$server = new $server_class ($parameters);
            ";

            my $server = eval $cmd;
            die "eval error: $@" unless ($server);
        }
    }
    eventLoop();
}

# ------------------------------------------------------------------------
# On line help and options.
# The full online help is the catenation of the header,
# the parameters description and the footer. Parameters description
#  is automatically computed.

# To customize: you can remove help specification, remove the
# configuration file, remove additional parameters and even remove
# everything related to configuration.
my $help_header = '
Template server. This script is an example of TCP/IP server that you can
customize to your needs. By default the example is a Fibonnaci number server. 
It replies to integer requests by the Fibonnacy function of the request.

usage: perl ServerTemplate.pl [options]';

my $help_footer = "Examples:
    to run the script as a Fibonnaci server on port 2345:
    perl server.pl -port 2345
    
    to run an echo server, or any dynamically supplied class:
    perl server.pl -port 2345 -server_class Events::Server \\
       -parameters \"port => 2345, factory => 'Events::EchoService'\"
       
    to run multiple servers:
    perl server.pl -port 2345 -port 2346 -port 2347
";

# If you specify a configuration file, it must exist.
# my $configFile = ExecutionContext::configFile();

my $config = new ScriptConfiguration(
    'header'     => $help_header,
    'footer'     => $help_footer,
    'scheme'     => SCRIPT,
    'parameters' => {
        port => {
            type        => "array",
            description => "list of port to listen",
            default     => [54321]
        },
        server_class => {
            type        => "string",
            description => "Server classs (default = Events::Server)"
        },
        parameters => {
            type        => "string",
            description => "parameters for the dynamic server"
        },
        fail => {
            type        => "flag",
            description => "when set, the server returns random errors"
        },
        async => {
            type => "flag",
            description =>
              "when set, the server postpones the replies for a random duration"
        },
        block_size => {
            type        => "string",
            description => "block size for sending",
            default     => 0
        }
    },
    #   'configFile' => $configFile
);

($config->value('port')) or croak "missing port parameter";    

my $script = new ServerTemplate( 
    config       => $config,
    loggerName   => "Test",
);
$script->run();
