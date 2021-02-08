#!/usr/bin/perl -w
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

Log::Log4perl->easy_init($INFO);
my $log = get_logger();

# options declaration
my $help    = 0;
my $verbose = 0;
my $host    = "localhost";    # The host to test.
my $port    = 1234;
my $binary  = "";

# others global variables
my $options = {
	'help'     => \$help,
	'verbose!' => \$verbose,
	'binary'   => \$binary,
	'ports=i'  => \$port
};

my $descriptions = {
	'help'     => "displays the online help. default=" . $help,
	'verbose!' => "switches on verbose mode. default=" . $verbose,
	'binary'   => "binary mode. default=" . $binary,
	'port=i'   => "list of ports to listen. default=" . $port
};

GetOptions( %{$options} );

if ($help) {
	usage( $options, $descriptions );
	exit;
}

if ($verbose) {
	say "port=$port";
}

my $filter = ($binary) ? POE::Filter::Binary->new() : POE::Filter::Line->new();

POE::Component::Client::TCP->new(
	RemoteAddress => $host,
	RemotePort    => $port,
	#  Filter        => "POE::Filter::Reference",
    Filter => $filter,
	Connected    => \&connected_cb,
	ConnectError => \&connectedError_cb,
	ServerInput => \&serverInput_cb,
);

$poe_kernel->run();
exit 0;

sub connected_cb {
	my $j = "teste";
	$log->info("connected to $host:$port ...");

	$_[HEAP]->{count} = 0;
	$_[HEAP]->{server}->put("Hello world");
}

sub connectedError_cb {
	$log->error("could not connect to $host:$port ...");
}

sub serverInput_cb {
	#when the server answer the question
	my ( $kernel, $heap, $input ) = @_[ KERNEL, HEAP, ARG0 ];
	$log->info("got result from $host:$port ... YAY!");

	#print to screen the result
	$log->info("<- $input");
	$_[HEAP]->{count}++;
	if ( $_[HEAP]->{count} < 100000 ) {
		my $cnt = $_[HEAP]->{count};
		$_[HEAP]->{server}->put( $_[HEAP]->{count} );
	}
	else {
		exit;
	}
}
