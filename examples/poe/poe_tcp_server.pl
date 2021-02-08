#!/usr/bin/perl

# ------------------------------------------------------------------------
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
use Log::Log4perl qw(:easy);
use Data::Dumper;

# Include POE, POE::Component::Server::TCP and POE::Filter::SSL (at least 0.17!).
use POE qw(
  Component::Server::TCP
  Filter::SSL
  Filter::Line
  Filter::Stackable
);

Log::Log4perl->easy_init($INFO);
my $log = get_logger();

# options declaration
my $help             = 0;
my $verbose          = 0;
my @default_ports    = (1234);
my @ports            = ();
my $block_size       = 0;
my $ssl              = '';
my $silence_timeout  = 0;
my $response_timeout = 0;
my $mode             = "echo";

# servers modes: echo server, telnet fibonnaci server or binary time server
# echo server just returns what they have received.
# fibonnacci servers computes the fibonnaci value of integer received in
# ASCII integers (one per line)
# The binary server returns either GMT or local time encoded according a binary 
# TLV protocol.

# CLI parameter description
my $options = {
	'help'         => \$help,
	'verbose!'     => \$verbose,
	'binary'       => sub {$mode = "binary"},
    'echo'         => sub {$mode = "echo"},
    'fibonnaci'    => sub {$mode = "fibonnacy"},
	'ssl=s'        => \$ssl,
	'block_size=i' => \$block_size,
	'ports=i@'     => \@ports
};

# CLI parameters documentation for --help option
my $descriptions = {
	'help'         => "displays the online help. default=" . $help,
	'verbose!'     => "switches on verbose mode. default=" . $verbose,
    'echo'         => "switch on echo mode (default).",
    'fibonnaci'    => "switch on fibonnaci mode.",
    'binary'       => "switch on binary mode.",
	'ssl=s'        => "password. Switches on ssl mode. default=" . $ssl,
	'block_size=i' => "blocks size. default=" . $block_size,
	'ports=i@'     => "list of ports to listen. default=("
	  . join( ",", @default_ports ) . ")"
};

# Analyse CLI parameters
GetOptions( %{$options} );

if ($help) {
	usage( $options, $descriptions );
}

@ports = @default_ports unless (@ports);

if ($verbose) {
	say "mode=$mode, block_size=$block_size, ports=["
	  . join( ", ", @ports )
	  . "], ssl=$ssl";
}

# default filter = POE::Filter::Line
# It is specified it anyway because it could be replaced
my $filter = POE::Filter::Line->new();
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
##########################################################################

# ------------------------------------------------------------------------
# method: usage
# Print the script usage and exit
# ------------------------------------------------------------------------
sub usage {

	my ( $options, $desc ) = @_;

    say "Example of multi client TCP/IP server using POE, the Perl Object Environement.";
    
	say "usage: perl $0 (options)*";
	foreach my $opt ( keys( %{$options} ) ) {
		printf( "\t%-15s => %s\n",
			$opt, exists( $desc->{$opt} ) ? $desc->{$opt} : '' );
	}
	exit;	
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
    return undef unless validate(
      $_[HEAP]{remote_ip}, $_[HEAP]{remote_port}
    );

    # SSLify the socket, which is in $_[ARG0].
    my $socket = eval { Server_SSLify($_[ARG0]) };
    return undef if $@;

    # Return the SSL-ified socket.
    return $socket;
  }