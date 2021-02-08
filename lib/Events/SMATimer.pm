# ----------------------------------------------------------------------------
#
# Title: Class Events::SMATimer
#
# File - Events/SMATimer.pm
# Author - frederic
#
# Name:
#
#    package Events::SMATimer
#
# Abstract:
#
#    SMATimer are objects used to handle timeouts with the state machine
#    automatom (SMA) module.
# ----------------------------------------------------------------------------
package Events::SMATimer;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Log::Log4perl;
use Events::Timer;
use Events::SMA;

$VERSION = 1;

@ISA = qw(Events::Timer);


# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift; 

    my %attr = @_;

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    # Others initialisation
    $Self->{'timeoutNumber'} = 0;
    exists ($Self->{'sma'}) or die "sma not defined";
    exists ($Self->{'event'}) or die "event not defined";
    exists ($Self->{'name'}) or $Self->{'name'} = 'timer';
}


# ----------------------------------------------------------------------------
# method: timeout
#
#    Callback called when the timeout expires.
# ----------------------------------------------------------------------------
sub timeout {
    my ($Self) = @_;
    
    $Self->{'timeoutNumber'}++;
    $Self->trace("Timeout $Self->{name}");

	# just signal the event to the SMA
	$Self->{'sma'}->signal($Self->{'event'}, $Self->{'name'}, $Self->{'timeoutNumber'});
}

1;
