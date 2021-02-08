#!/usr/bin/perl
# Title:  TCP/IP server Template
#
# Abstract:
#
#    Example of TCP/IP server
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
use warnings;
use strict;
use 5.010;
use Getopt::Long;
use Log::Log4perl qw(get_logger);
use Data::Dumper;
use File::Basename qw(fileparse);

use lib "$ENV{'FTF'}/lib";

# Include POE, POE::Component::Server::TCP and POE::Filter::SSL (at least 0.17!).
use POE qw(
  Component::Server::TCP
  Filter::Line
  Filter::Stackable
  Filter::Binary
);

# Logging
Log::Log4perl->init($ENV{'FTF'}. "/conf/log4perl.conf");
my $log = get_logger("Tests.Network");
# say Dumper($log);

# options declaration
my $help             = 0;
my $verbose          = 0;
my @ports            = (1234);
my $block_size       = 0;
my $binary           = "";
my $silence_timeout  = 0;
my $response_timeout = 0;

# CLI parameter description
my $options = {
	'help'         => \$help,
	'verbose!'     => \$verbose,
	'binary'       => \$binary,
	'block_size=i' => \$block_size,
	'ports=i@'     => \@ports
};

# CLI parameters documentation for --help option
my $descriptions = {
	'help'         => "displays the online help. default=" . $help,
	'verbose!'     => "switches on verbose mode. default=" . $verbose,
	'binary'       => "binary mode. default=" . $binary,
	'block_size=i' => "blocks size. default=" . $block_size,
	'ports=i@'     => "list of ports to listen. default=("
	  . join( ",", @ports ) . ")"
};

# Analyse CLI parameters
GetOptions( %{$options} );

if ($help) {
	usage( $options, $descriptions );
	exit;
}

if ($verbose) {
	say "block_size=$block_size, ports=["
	  . join( ", ", @ports )
	  . "]";
}

# default filter = POE::Filter::Line
# It is specified it anyway because it could be replaced
my $filter = ($binary) ? POE::Filter::Binary->new() : POE::Filter::Line->new();
my $filter_stack = POE::Filter::Stackable->new();
$filter_stack->push($filter);

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
##########################################################################

# ------------------------------------------------------------------------
# method: usage
# Print the script usage and exit
# ------------------------------------------------------------------------
sub usage {

	my ( $options, $desc ) = @_;

	say "usage: perl $0 (options)*";
	foreach my $opt ( keys( %{$options} ) ) {
		printf( "\t%-15s => %s\n",
			$opt, exists( $desc->{$opt} ) ? $desc->{$opt} : '' );
	}
}

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

	# The following line is needed to do the SSL handshake!
	print "Session ", $session->ID(), " got input: $input\n";
	$heap->{client}->put($input);
}

sub handle_client_pre_connect {

    # Make sure the remote address and port are valid.
    return undef unless validate(
      $_[HEAP]{remote_ip}, $_[HEAP]{remote_port}
    );

    # SSLify the socket, which is in $_[ARG0].
    my $socket = eval { Server_SSLify($_[ARG0]) };
    return undef if $@;

    # Return the SSL-ified socket.
    return $socket;
  }
  
package main;

# ------------------------------------------------------------------------
# routine: logFilename
#
# Return:
#     - The name of the log file.
# ------------------------------------------------------------------------
my $logFilename;
sub logFilename {

    my ( $base, $dir, $ext ) = fileparse( $0, ".pl" );
    return $base . ".log";
}
  