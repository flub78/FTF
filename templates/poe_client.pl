#!/usr/bin/perl -w

# ------------------------------------------------------------------------
# Title: Simple TCP/IP client template using POE
#
# Source - <file:../poe_client.pl.html>
#
# Abstract:
#
#    Example of TCP/IP client using POE (Perl Object Environment).
#
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
use POE::Filter::SSL;
  

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
my $mode = "echo";
my $ssl           = '';

# others global variables
my $options = {
    'help'     => \$help,
    'verbose!' => \$verbose,
    'binary'   => \$binary,
    'ssl'      => \$ssl,
    'host=s'   => \@hosts
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
       -ssl             (flag). Switches on ssl mode.
       -host host:port  host and port to connect to (\":port\" accepted for localhost)
        
Exemple:

    to run the script as a Fibonnaci client on localhost, port 54321:
    perl $name -host :54321
    
    to start multiple clients
    perl $name -host :2345 -host :2346 -host :2347
    
    to connect with SSL
    perl poe_client.pl -ssl
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

my $filter = ($binary) ? POE::Filter::Binary->new() : POE::Filter::Line->new();

if ($ssl) {
    $filter = [ "POE::Filter::SSL", client => 1 ];
}

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
# routine: connected_cb
#
# Callback invoked on connection
# ------------------------------------------------------------------------
sub connected_cb {
    $log->info("connected to $host:$port ...");

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
}

# ------------------------------------------------------------------------
# routine: serverInput_cb
#
# when the server answer the question
# ------------------------------------------------------------------------
sub serverInput_cb {
  
    my ( $kernel, $heap, $input ) = @_[ KERNEL, HEAP, ARG0 ];

    #print to screen the result
    $log->info("<- $host:$port: $input");
    $_[HEAP]->{count}++;
    if ( $_[HEAP]->{count} < 10 ) {
        # next request
        my $cnt = $_[HEAP]->{count};
        $_[HEAP]->{server}->put( $_[HEAP]->{count} );
    }
    else {
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
