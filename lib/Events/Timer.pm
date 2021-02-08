# ----------------------------------------------------------------------------
#
# Title: Class Events::Timer
#
# File - Events/Timer.pm
# Author - frederic
#
# Name:
#
#    package Events::Timer
#
# Abstract:
#
#    Timer objects of our network toolbox. They are registered with 
#    the events manager and have a timeout method which is invoked
#    when the time is over.
# ----------------------------------------------------------------------------
package Events::Timer;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Exporter;
use Events::EventsManager;
use ClassWithLogger;

$VERSION = 1;

@ISA = qw(ClassWithLogger);


# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift; 

    my %attr = @_;
    $Self->ClassWithLogger::_init(@_);

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    # Others initialisation
    $Self->{'timeoutNumber'} = 0;
}


# ----------------------------------------------------------------------------
# method: cancel
#
#    Method to disable the timer
# ----------------------------------------------------------------------------
sub cancel {
    my ($Self) = @_;
    
    $Self->trace("cancel($Self->{'name'})");
    Events::EventsManager::removeTimer ($Self);
}

# ----------------------------------------------------------------------------
# method: start
#
#    Method to start or restart a timer. Use previous setting when
#    no parameters are passed.
#    
#    Parameters:
#       $delay - the timer will trigger alarm after $delay seconds.
#       $periodic - when defined the timer will be reactivated
# ----------------------------------------------------------------------------
sub start {
    my ($Self, $delay, $periodic) = @_;
    
    $Self->{'delay'} = $delay if defined($delay);
    my $n;
    if (defined($periodic)) {
    	$Self->{'periodic'} = $periodic;
    }
    my $strPeriod = (defined ($Self->{'periodic'})) ? $Self->{'periodic'} : "0"; 
    $Self->trace("start(delay = $Self->{'delay'}, periodic = $strPeriod)");
    Events::EventsManager::registerTimer ($Self, $Self->{'delay'}, $Self->{'periodic'});
}

# ----------------------------------------------------------------------------
# method: timeout
#
#    Callback called when the timeout expires.
# ----------------------------------------------------------------------------
sub timeout {
    my ($Self) = @_;
    
    $Self->{'timeoutNumber'}++;
    $Self->info("Timeout $Self->{name}");
}

sub timeoutNumber {return $_[0]->{'timeoutNumber'};}
1;
