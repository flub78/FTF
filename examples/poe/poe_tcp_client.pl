#!/usr/bin/perl -w

# ------------------------------------------------------------------------
# Title:  TCP/IP client Template
#
# Abstract:
#
#    Example of TCP/IP client
#
#    This example may be uses as a template for a TCP/IP server using POE.
#
#    The example must remain as simple as possible but be as close as possible
#    of a real world program.
#
#    Contents:
#    - NaturalDoc style inline documentation
#    - Command line parameters
#    - Log4Perl logging
#    - --help option
#    - multiple host server
#    - SSL support
#    - support for line or binary protocol
# ------------------------------------------------------------------------
use strict;
use 5.010;

use Getopt::Long;
use Log::Log4perl qw(:easy);
use POE;
use POE::Component::Client::TCP;
use POE::Filter::Reference;
use POE::Filter::SSL;
use Data::Dumper;

Log::Log4perl::init("$ENV{'FTF'}/conf/log4perl.conf");
my $log = Log::Log4perl->get_logger('Network'); # log4perl.logger.script

my $defaulthost = "localhost";
my $defaultport = 1234;

# options declaration
my $help          = 0;
my $verbose       = 0;
my @default_hosts = ("$defaulthost:$defaultport");
my @hosts         = ();
my $ssl           = '';
my $binary        = "";
my $iterations    = 3;

# others global variables
my $filter = undef;

my $options = {
    'help'     => \$help,
    'verbose!' => \$verbose,
    'binary'   => \$binary,
    'ssl'      => \$ssl,
    'hosts=s'  => \@hosts,
    'iterations=i'  => \$iterations,
};

my $descriptions = {
    'help'     => "displays the online help. default=" . $help,
    'verbose!' => "switches on verbose mode. default=" . $verbose,
    'binary'   => "binary mode. default=" . $binary,
    'ssl'      => "(flag). Switches on ssl mode. default=" . $ssl,
    'host=s'   => "list of hosts to listen. default=(" . join( ", ", @default_hosts ),
    'iterations=i'  => "number of iterations, default=" . $iterations
};

GetOptions( %{$options} );

if ($help) {
    usage( $options, $descriptions );
}

@hosts = @default_hosts unless (@hosts);

if ($verbose) {
    say "port=(" . join( ", ", @hosts ) . ")";
}

if ($ssl) {
    $filter = [ "POE::Filter::SSL", client => 1 ];
}

foreach my $hostport (@hosts) {

    # $log->info("connecting to $hostport");

    my $host = $defaulthost;
    my $port = $defaultport;
    if ( $hostport =~ /(.*):(\d*)/ ) {
        $host = $1 if ($1);
        $port = $2 if ($2);
    }

    POE::Component::Client::TCP->new(
        Args => [$host, $port],
        RemoteAddress => $host,
        RemotePort    => $port,

        #  Filter        => "POE::Filter::Reference",
        Filter       => $filter,
        Started      => \&started_cb,
        Connected    => \&connected_cb,
        ConnectError => \&connectedError_cb,
        ServerInput  => \&serverInput_cb,
    );
}

$poe_kernel->run();
exit 0;
##########################################################################

# ------------------------------------------------------------------------
# method: usage
# Print the script usage and exit
# ------------------------------------------------------------------------
sub usage {

    my ( $options, $desc ) = @_;

    say "example of TCP/IP client using POE, the Perl Object Environement";
    say "usage: perl $0 (options)*";
    foreach my $opt ( keys( %{$options} ) ) {
        printf( "\t%-15s => %s\n",
            $opt, exists( $desc->{$opt} ) ? $desc->{$opt} : '' );
    }
    exit;
}

# ------------------------------------------------------------------------
# method: started_cb
# Callback invoked when the client is started
# ------------------------------------------------------------------------
sub started_cb {
    $_[HEAP]->{host} = $_[ARG0];
    $_[HEAP]->{port} = $_[ARG1];
}

# ------------------------------------------------------------------------
# method: connected_cb
# Callback invoked when the connection is established
# ------------------------------------------------------------------------
sub connected_cb {
    my $j = "teste";

    $log->info("connected to " . $_[HEAP]->{host} . ':' . $_[HEAP]->{port});

    $_[HEAP]->{count} = 0;
    $_[HEAP]->{server}->put("Hello world");
}

# ------------------------------------------------------------------------
# method: connectedError_cb
# Callback invoked in case of error during connection
# ------------------------------------------------------------------------
sub connectedError_cb {
    $log->error("could not connect to " . $_[HEAP]->{host} . ':' . $_[HEAP]->{port});
}

# ------------------------------------------------------------------------
# method: serverInput_cb
# Callback invoked when data are received on the socket
# ------------------------------------------------------------------------
sub serverInput_cb {

    #when the server answer the question
    my ( $kernel, $heap, $input ) = @_[ KERNEL, HEAP, ARG0 ];

    my $host = $_[HEAP]->{host};
    my $port = $_[HEAP]->{port};

    #print to screen the result
    $log->info("$host:$port <- $input");
    $_[HEAP]->{count}++;
    if ( $_[HEAP]->{count} < $iterations ) {
        $_[HEAP]->{server}->put( $_[HEAP]->{count} );
        
#        POE::Kernel->yield();
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
