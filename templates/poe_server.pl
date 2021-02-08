#!/usr/bin/perl -w

# ------------------------------------------------------------------------
# Title:  TCP/IP Server template using POE
#
# Source - <file:../poe_server.pl.html>
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
#    This version is based on POE event loop. I itent to replace the
#    event loop to get better performance, lower ressources consumption
#    and lower maintainance.
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
#    perl ServerTemplate.pl -port 2345
#
#    to run it as an echo server, or any dynamically supplied class:
#    perl ServerTemplate.pl -port 2345 -server_class Events::Server \
#       -parameters "port => 2345, factory => 'Events::EchoService'"
#
#    to run multiple servers:
#    perl ServerTemplate.pl -port 2345 -port 2346 -port 2347
#
# (end)
#
# Logger:
#
# Use the network logger to control the verbosity level of this script. File $FTF/conf/log4perl.conf.
# (Start code)
# log4perl.logger.Tests = ALL, Console
# (end)
# ------------------------------------------------------------------------
use strict;
use 5.010;

use Getopt::Long;
use Log::Log4perl qw(:easy);
use lib "$ENV{'FTF'}/lib";
use POE;
use Data::Dumper;

# Include POE, POE::Component::Server::TCP and POE::Filter::SSL (at least 0.17!).
use POE qw(
  Component::Server::TCP
  Filter::SSL
  Filter::Line
  Filter::Stackable
);

# use ExecutionContext;
# use ScriptConfiguration;

use Carp;

# Script name
my $name = $0;
Log::Log4perl::init("$ENV{'FTF'}/conf/log4perl.conf");
my $log = Log::Log4perl->get_logger('Network');    # log4perl.logger.script

# options declaration
my $help             = 0;
my $verbose          = 0;
my @ports            = (1234);
my $block_size       = 0;
my $ssl              = '';
my $binary           = "";
my $silence_timeout  = 0;
my $response_timeout = 0;

# CLI parameter description
my $options = {
    'help'         => \$help,
    'verbose!'     => \$verbose,
    'binary'       => \$binary,
    'ssl=s'        => \$ssl,
    'block_size=i' => \$block_size,
    'ports=i@'     => \@ports
};

# CLI parameters documentation for --help option
my $descriptions = {
    'help'         => "displays the online help. default=" . $help,
    'verbose!'     => "switches on verbose mode. default=" . $verbose,
    'binary'       => "binary mode. default=" . $binary,
    'ssl=s'        => "password. Switches on ssl mode. default=" . $ssl,
    'block_size=i' => "blocks size. default=" . $block_size,
    'ports=i@'     => "list of ports to listen. default=("
      . join( ",", @ports ) . ")"
};

# ------------------------------------------------------------------------
# routine: usage
# ------------------------------------------------------------------------
sub usage {
    my ( $options, $desc ) = @_;

    say "
TCP/IP server template. 

usage: perl $name [options]

Options:";
    foreach my $opt ( keys( %{$options} ) ) {
        printf( "\t%-15s => %s\n",
            $opt, exists( $desc->{$opt} ) ? $desc->{$opt} : '' );
    }
    say "        
Exemple:

    to run the script as a Fibonnaci server on port 2345:
    perl server.pl -port 2345
    
    to run an echo server, or any dynamically supplied class:
    perl server.pl -port 2345 -server_class Events::Server \\
       -parameters \"port => 2345, factory => 'Events::EchoService'\"
       
    to run multiple servers:
    perl server.pl -port 2345 -port 2346 -port 2347
    
    to accept SSL connections
    ./poe_server.pl -ssl 1      (prompted password = eeeeee)
";
    exit();
}

# log invocation command
$log->info( $0 . " " . join( " ", @ARGV ) );

# parse the CLI
GetOptions( %{$options} );
if ($help) {

    # print usage and exit
    usage( $options, $descriptions );
}

my $filter = ($binary) ? POE::Filter::Binary->new() : POE::Filter::Line->new();
my $filter_stack = POE::Filter::Stackable->new();
$filter_stack->push($filter);

if ($ssl) {
    my $ssl_filter = [
        "POE::Filter::SSL",
        crt   => 'server.crt',
        key   => 'server.key',
        debug => 1
    ];
    $filter_stack = $ssl_filter;
    say Dumper($ssl_filter);

    # $filter_stack->push($ssl_filter);
}

# Start TCP servers.  Client input will be logged to the console and
# echoed back to the client, one line at a time.
foreach my $port (@ports) {
    $log->info("starting server on $port");

    POE::Component::Server::TCP->new(
        Alias => "server" . $port,
        Port  => $port,

        # You need to have created certificates for server mode!
        ClientFilter => $filter_stack,
        ClientInput  => \&input_cb
    );
}

# Start the event loop
$poe_kernel->run();
exit 0;

# ------------------------------------------------------------------------
# routine: run
#
#  Scrip main method.
# ------------------------------------------------------------------------
#sub run {
#    my $Self = shift;
#
#    my @servers      = @{ $Self->{'config'}->value('port') };
#    my $server_class = $Self->{'config'}->value('server_class');
#    my $parameters   = $Self->{'config'}->value('parameters');
#    my $fail         = $Self->{'config'}->value('fail');
#    my $async        = $Self->{'config'}->value('async');
#    my $block_size   = $Self->{'config'}->value('block_size');
#
#    # for flags to be 0, null string is not convenient in string interpretation
#    $fail  = 0 unless ($fail);
#    $async = 0 unless ($async);
#
#    foreach my $port (@servers) {
#
#        $Self->info("listening to $port");
#
#        if ( !defined($server_class) || ( $server_class eq "" ) ) {
#
#            # server class is not defined, dedicated script
#            # You will be warn of missing classes at compile time
#            # Use this syntax to adapt it to your own needs.
#            my $codec  = new CODECs::Telnet();
#            my $server = new PoeEvents::Server(
#                port    => $port,
#                factory => 'FiboService',
#                params =>
#"loggerName => \"Tests\", fail => $fail, async => $async, block_size => $block_size",
#                codec => $codec,
#            );
#
#        }
#        else {
#
#            # type of service is defined dynamically
#            # you will be warned of missing classes at run time.
#            my $cmd = "
#               require $server_class;
#               my \$server = new $server_class ($parameters);
#            ";
#
#            my $server = eval $cmd;
#            die "eval error: $@" unless ($server);
#        }
#    }
#    eventLoop();
#}

#($config->value('port')) or croak "missing port parameter";
#
#my $script = new ServerTemplate(
#    config       => $config,
#    loggerName   => "Test",
#);
#$script->run();

# ------------------------------------------------------------------------
# method: input_cb
# Routine called back whane data is received
#
# Parameters:
# session - an hexadecimal string
# heap - direct access to the session heap
# input - received data
# ------------------------------------------------------------------------
sub input_cb {
    my ( $session, $heap, $input ) = @_[ SESSION, HEAP, ARG0 ];

    #    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

   #    return unless (POE::Filter::SSL::doHandshake($heap->{client}, $filter));

    # The following line is needed to do the SSL handshake!
    print "Session ", $session->ID(), " got input: $input\n";
    $heap->{client}->put($input);
}

# ------------------------------------------------------------------------
# method: handle_client_pre_connect
# ------------------------------------------------------------------------
sub handle_client_pre_connect {
    # Make sure the remote address and port are valid.
    return undef unless validate( $_[HEAP]{remote_ip}, $_[HEAP]{remote_port} );

    # SSLify the socket, which is in $_[ARG0].
    my $socket = eval { Server_SSLify( $_[ARG0] ) };
    return undef if $@;

    # Return the SSL-ified socket.
    return $socket;
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
