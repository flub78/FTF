#!/usr/bin/perl -w
#
# Title: POE simple example No 3
#
# Abstract:
#
# Demonstrates session communication
# ------------------------------------------------------------------------
use strict;
use POE;       # Auto-includes POE::Kernel and POE::Session.
use 5.010;

sub handler_start {
	POE::Kernel->alias_set('logger');
}

sub handler_debug {
	my @args = @_[ ARG0 .. $#_ ];
	say @args;
}

sub handler_stop {
	print "Session ", $_[SESSION]->ID, " has stopped.\n";
}

POE::Session->create(
	inline_states => {
		_start => \&handler_start,
		debug  => \&handler_debug
	}
);

POE::Session->create(
	inline_states => {
		_start => sub {
			POE::Kernel->yield( tick => 3 );
		},
		tick => sub {
			my $i = $_[ARG0];

			# log message
			POE::Kernel->post( logger => debug => "test - i = $i" );
			POE::Kernel->yield( tick => $i - 1 ) if $i;
		  }
	}
);

POE::Kernel->run();
exit;
