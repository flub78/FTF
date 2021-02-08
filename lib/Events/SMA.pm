# ----------------------------------------------------------------------------
# Title:  Class Events::SMA
#
# File - Events/SMA.pm
# Version - 1.0
#
# Name:
#
#       package Events::SMA
#
# Abstract:
#
#       State Machine Automaton based on <Events>.  SMA are handy during design phases, but
#       it is often more efficient to translate their logic into the code rather than
#       to to use a manager. There is one case however where there are really useful
#       it is in correlation with events driven programming. In this case it is
#       easier to let a SMA manage all the logic than to dispatch the code in a lot
#       of event handlers.
#
#       This implementation supports the following features.
#
#       - Type checking for states, events and transitions. To stay simple,
#       states and events are contained into strings, but ther is a check in all
#       routines than referenced states and events have been declared before.
#       If required, it will be possible to disable these controls for perfomance.
#
#       - Callback support. It is possible to attach callbacks on entry or exit
#       of states. Callbacks can be associated to all events or only one specific event.
#       There is also a callback invoked when the automaton reachs a final states.
#       It is really convenient to disable the event loop in this callback. That way
#       you just have to declare a bunch of servers, clients and other connectore, 
#       to define an automaton ans starts the event loop. The control return from 
#       the event loop when the automaton is in any final states.
#
#		(see sma.png)
#
#       Callbacks are invoked with the related state and event as first and second
#       parameters, then the parameters specified in the signal method.
#
#       It is possible to attach one global callback triggered when the SMA
#       enter and exit a state and also one callback for each event. If a global
#       and event specific callback are attached they are both invoked. Same
#       thing for exit.
#
#       (see triggers.png)
#
#       On exit callbacks are invoked with the current state still in the
#       transition departure state and on entry callbackas are invoked with
#       the current state already matching the arrival state.
#
#       *AVOID TO INCLUDE STATE CHANGES IN EXIT CALLBACKS* They would be
#       overwritten by the end of the state change statement.
#
#       Currently there is only support for one callback per state, per event
#       and per entry or exit, in the future it could be convenient to replace
#       that by a list of callbacks. That way different modules could attach their
#       own callback to a state and event and you would not have to supply
#       unique callback in charge of actions for all modules. This unique callback
#       model tends to break software modularity abstraction.
#
#       - Support for timeouts. Timerouts can be considered as automatic
#       transition triggering after a specified duration. Timeouts are attached
#       to states.  They are activated when the state becomes current
#       and are disabled when the automaton leaves the state. When the timers
#       expires they just trigger an event. The user must have defined a transition
#       for the event. When the transition let the automatom in the same state,
#       entry and exit callbacks are activated, the associated timer is
#       restarted and other timers are untouched.
#
#       It is a really safe model because, you are sure that timeouts are never
#       triggered in state in which you do not expect them and you do not
#       have to manually disable the timers when leaving states with the risk
#       to forgot one.
#
#       Once attached, the timeout are managed when the SMA enters the event
#       loop processing. This version is compatible with the Perl::Event event
#       loop.
#
# Support for nested states:
#
#       (see nested.png)
#
#       To simplify SMA design there is a support for nested states. By convention
#       nested states are named by dot separated strings. By example "test.phase1.A".
#       In fact it is always possible to find a non nested automatom equivalent to
#       one with nested states, but nesting can save a lot of writing.
#
#       In nested state automaton is is possible to attach callbacks to entry and exit
#       of group of states. It is also possible to define transitions with a group
#       as departure state. In this case the transition will be triggered on the event
#       signaling if the current state belongs to the group.
#
#       Nesting state group are not allowed as transition target states, because it
#       would require to specify an initial state for each subgroup. This choice could
#       be reconsidered to handle huge automatoms for which it would be useful
#       to hide implementation details. Currently the toolbox
#       is more oriented to support fast development of simples tests.
#
# Usage:
#
#       For convenience, it is possible to pass a hash to the object constructor. There is no
#       control that you do not change the SMA after you have started to process events
#       but self-modifying SMA are not really recommended. It is also why I did not provide methods
#       to delete states or transitions.
#
#       When you declare the SMA with a hash, I recommend the use of the check method which
#       performs some coherency controls.
#
# Example:
# (start code)
#    my $sma = new Events::SMA (
#        states => ['Initial', 'State1', 'State2', 'Terminal'],
#        events => ['A', 'B', 'Error'],
#        initial => 'Initial',
#        transitions => {
#            'Initial' => {'Start' => 'State1'},
#            'State1' => {'A' => 'State2',
#                         'B' => 'Terminal'
#            }
#        },
#        finals => {
#            'Terminal' => 1
#        }
#    );
# (end)
# ------------------------------------------------------------------------

########################################################################
package Events::SMA;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use Exporter;
use Data::Dumper;

use ClassWithLogger;
use Events::SMATimer;

$VERSION = 1;

@ISA = qw(ClassWithLogger);

use constant ONE_SHOT => 0;
use constant PERIODIC => 1;

use constant GROUP => 1;

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    # Call the parent initialization first
    $Self->ClassWithLogger::_init(@_);

    my %attr = @_;

    $Self->{'states'}      = [];
    $Self->{'events'}      = [];
    $Self->{'transitions'} = {};

    $Self->{'nestedState'} = 0;

    $Self->{'record'}  = 0;
    $Self->{'history'} = "";

    # Takes the new parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    # Initialisation
    if ( exists( $Self->{'initial'} ) ) {
        $Self->{'current'} = $Self->{'initial'};
    }
}

# ------------------------------------------------------------------------
# method: states accessors
#
# Set or get the list of states
#
# Parameters:
# list - list of states
#
# Returns: the list of states
# ------------------------------------------------------------------------
sub states {
    my $Self = shift;

    $Self->{states} = shift if @_;
    return $Self->{states};
}

# ------------------------------------------------------------------------
# method: initial accessor
#
# Set or get the initial state. When the initial state is set, the current
# state is also set.
#
# Parameters:
# $init - Initial state
#
# Returns: the initial state
# ------------------------------------------------------------------------
sub initial {
    my ( $Self, $init ) = @_;

    if ( defined($init) ) {
        $Self->existState($init) or die "State $init does not exist";
        $Self->{'initial'} = $init;
        $Self->{'current'} = $init;
    }
    return $Self->{'initial'};
}

# ------------------------------------------------------------------------
# method: current state accessor
#
# Set or get the current state. It is not really recommended to set
# the current state which is normally managed by the event method. Current
# state should evolved according to the defined transitions and occuring
# events. But we are in Perl, arent'we ? so if you want to mess up ...
#
# Parameters:
# list - Current state
#
# Returns: the current state
# ------------------------------------------------------------------------
sub current {
    my ( $Self, $current ) = @_;

    if ( defined($current) ) {
        $Self->existState($current) or die "Unknow state $current";
        $Self->{'current'} = $current;
    }
    return $Self->{'current'};
}

# ------------------------------------------------------------------------
# method: existState
#
# Check than a state or a state group exist. When the group parameter
# is not set, checks for exact matching. When it is set, checks also
# for group mathcing.
#
# Parameters:
# state - name of the state to check
# group - boolean, support state group
#
# Return: a boolean value
# ------------------------------------------------------------------------
sub existState {
    my ( $Self, $state, $group ) = @_;

    foreach my $s ( @{ $Self->states() } ) {
        if ( $s eq $state ) {
            return 1;
        }
        if ($group) {
            if ( $s =~ "$state\." ) {
                return 1;
            }
        }
    }
    return 0;
}

# ------------------------------------------------------------------------
# method: addState
#
# add a new State
#
# Parameters:
# state - name of the state to add
# ------------------------------------------------------------------------
sub addState {
    my ( $Self, $state ) = @_;

    return if $Self->existState($state);
    push( @{ $Self->{states} }, $state );
}

# ------------------------------------------------------------------------
# method: events accessors
#
# Set or get the list of eventss
#
# Parameters:
# list - list of events
# ------------------------------------------------------------------------
sub events {
    my $Self = shift;

    $Self->{events} = shift if @_;
    return $Self->{events};
}

# ------------------------------------------------------------------------
# method: existEvent
#
# check than an event exist
#
# Parameters:
# event - name of the event to check
#
# Return: a boolean value
# ------------------------------------------------------------------------
sub existEvent {
    my ( $Self, $event ) = @_;

    foreach my $e ( @{ $Self->events() } ) {
        if ( $e eq $event ) {
            return 1;
        }
    }
    return 0;
}

# ------------------------------------------------------------------------
# method: addEvent
#
# add a new event
#
# Parameters:
# event - event to add
# ------------------------------------------------------------------------
sub addEvent {
    my ( $Self, $event ) = @_;

    return if $Self->existEvent($event);
    push( @{ $Self->{events} }, $event );
}

# ------------------------------------------------------------------------
# method: addTransition
#
# add a new transition.
#
# Parameters:
# departure - departure state
# event - triggering event
# arrival - arrival state
# ------------------------------------------------------------------------
sub addTransition {
    my ( $Self, $departure, $event, $arrival ) = @_;

    $Self->info(
        "new transition " . $departure . " - " . $event . " - " . $arrival );

    $Self->existState( $departure, GROUP )
      or die "departure state $departure does not exist";
    $Self->existState($arrival) or die "arrival state $arrival does not exist";
    $Self->existEvent($event)   or die "event $event does not exist";
    $Self->{'transitions'}->{$departure}->{$event} = $arrival;
}

# ------------------------------------------------------------------------
# routine: _subStates (private)
#
# Return a list of all possible state matching level of a state. Returns
# the entry string when there is no substates.
#
# Ex: _subStates ("test.phase1.A") returns
# ("test", "test.phase1", "test.phase1.A" )
#
# Parameters:
# state - the state to analyze
# ------------------------------------------------------------------------
sub _subStates {
    my ($state) = @_;

    my @list      = split( /\./, $state );
    my $str       = shift(@list);
    my @stateList = ($str);

    foreach my $level (@list) {
        $str .= "." . $level;
        push( @stateList, $str );
    }
    return @stateList;
}

# ------------------------------------------------------------------------
# routine: _leftStates (private)
#
# Return a list of the states that are left durind a transition.
#
# Ex: _leftStates ("test.category1.group2.A", "test.category1.group3.set2.C")
# should return
# ("test.category1.group2.A", "test.category1.group2")
# The states "test.category1" and "test" are common to start and destination
# they are not left.
#
# Parameters:
# departure - initial state
# arrival - target state
# ------------------------------------------------------------------------
sub _leftStates {
    my ( $departure, $arrival ) = @_;

    my @start       = split( /\./, $departure );
    my @destination = split( /\./, $arrival );
    my @states      = ();

    # identify common parts
    my $i = 0;
    while ( $i < @start ) {
        last if ( $start[$i] ne $destination[$i] );
        push( @states, $start[$i] );
        $i++;
    }

    # assertion: $i is the first index of non equal state
    my @list = ();
    while ( $i < @start ) {
        push( @states, $start[$i] );
        push( @list, join( ".", @states ) );
        $i++;
    }
    return reverse(@list);
}

#print join (", ", _leftStates ("test.category1.group2.A", "test.category1.group3.set2.C")), "\n";
#print join (", ", _leftStates ("A", "C")), "\n";
#print join (", ", _leftStates ("D", "D")), "\n";
#die;

# ------------------------------------------------------------------------
# routine: _enteredStates (private)
#
# Return a list of the states that are entered durind a transition.
#
# Ex: _enteredStates ("test.category1.group2.A", "test.category1.group3.set2.C")
# should return
# ("test.category1.group3", "test.category1.group3.set2", "test.category1.group3.set2.C")
# The states "test.category1" and "test" are common to start and destination, they
# are not entered.
#
# Parameters:
# departure - initial state
# arrival - target state
# ------------------------------------------------------------------------
sub _enteredStates {
    my ( $departure, $arrival ) = @_;

    my @start       = split( /\./, $departure );
    my @destination = split( /\./, $arrival );
    my @states      = ();

    # identify common parts
    my $i = 0;
    while ( $i < @destination ) {
        last if ( $start[$i] ne $destination[$i] );
        push( @states, $start[$i] );
        $i++;
    }

    # assertion: $i is the first index of non equal state
    my @list = ();
    while ( $i < @destination ) {
        push( @states, $destination[$i] );
        push( @list, join( ".", @states ) );
        $i++;
    }
    return @list;
}

#print join (", ", _enteredStates ("test.category1.group2.A", "test.category1.group3.set2.C")), "\n";
#print join (", ", _enteredStates ("A", "C")), "\n";
#print join (", ", _enteredStates ("D", "D")), "\n";
#die;

# ------------------------------------------------------------------------
# method: signal
#
# Triggers a transition. Update the current state. This method also invokes
# the attached entry and exit callbacks. Of course exit callbacks are
# called before entry callabcks.
#
# Parameters:
# event - happening event
# parameters - all other parameters are passed to the callback
#
# Returns: the current (arrival) state
# ------------------------------------------------------------------------
sub signal {
    my $Self  = shift;
    my $event = shift;
    my @args  = @_;

    # First check the validity of the transition
    $Self->existEvent($event)
      or die "unknown event $event";

    my $departure = $Self->{'current'};
    my $arrival;
    my $group;

    # look for a transition
    foreach my $grp ( _subStates($departure) ) {
        $arrival = $Self->{'transitions'}->{$grp}->{$event};
        $group   = $grp;
        last if ($arrival);
    }

    defined($arrival)
      or die "illegal transition " . $departure . " -(" . $event . ")";

    # a transition has been found
    $Self->warn( $group . " --(" . $event . ")--> " . $arrival );
    if ( $Self->{'record'} ) {
        $Self->{'history'} .=
          $group . " --(" . $event . ")--> " . $arrival . "\n";
    }

    # disable all timers of the departure states
    my @exited = _leftStates( $departure, $arrival );
    foreach my $dep ( @exited ) {
        # print "disabling timer for $dep\n";
        # we do not disable timers when we stay on the same state to not reset
        # not yet expired timeouts. SMA uses periodic timers.
        if ( exists( $Self->{'timers'}->{$dep} ) ) {
            foreach my $t ( @{ $Self->{'timers'}->{$dep} } ) {
                $Self->trace("$dep disabling timer");
                $t->cancel();
            }
        }
    }

    # invoke the onExit callbacks
    $Self->_call( 'onExit', $departure, $event, @args ) if ($arrival eq $departure);
    foreach my $dep ( @exited ) {
        $Self->trace("$dep exit callback");
        $Self->_call( 'onExit', $dep, $event, @args );
    }

    # set current state
    $Self->{'current'} = $arrival;
    
    # on final callback
    if (($Self->isFinal($arrival)) && (!$Self->isFinal($departure))) {
        $Self->_call( 'onFinal', $arrival, $event, @args );
    }

    # and enable the timers of the arrival states
    my @entered = _enteredStates( $departure, $arrival );
    foreach my $arr ( @entered ) {
        if ( exists( $Self->{'timers'}->{$arr} ) ) {
            foreach my $t ( @{ $Self->{'timers'}->{$arr} } ) {
                $Self->trace("$arr starting timer");
                $t->start();
            }
        }
    }

    # invoke the onEntry callbacks. This treatment is done after
    # the timer activation because callback could contain calls
    # to event. In this order all treatments associated to the inital
    # change of state are done before the next change. The draw back
    # it that timers are started before callback invocation and we do not
    # have control on their execution time
    foreach my $arr ( @entered ) {
        $Self->trace("$arr entry callback");
        $Self->_call( 'onEntry', $arr, $event, @args );
    }
    $Self->_call( 'onEntry', $arrival, $event, @args ) if ($arrival eq $departure);

    return $arrival;
}

# ------------------------------------------------------------------------
# method: _call (private)
#
# invoke transition callbacks
# ------------------------------------------------------------------------
sub _call {
    my $Self   = shift;
    my $onWhat = shift;
    my $state  = shift;
    my $event  = shift;
    my @args   = @_;

    my $callback;

    if ($onWhat eq 'onFinal') {
        if (exists($Self->{'callbacks'}->{'onFinal'})) {
            $callback = $Self->{'callbacks'}->{'onFinal'};
            $Self->warn( "calling callback ($onWhat, $state, $callback)"); 
            &$callback( $state, $event, @args );        
        }
        return;
    }
    $callback = $Self->{'callbacks'}->{$onWhat}->{$state}->{'_allEvents'};
    if ( defined($callback) ) {
        $Self->warn( "calling callback ($onWhat, $state, _allEvents)"); 
        &$callback( $state, $event, @args );
    }

    $callback = $Self->{'callbacks'}->{$onWhat}->{$state}->{$event};
    if ( defined($callback) ) {
        $Self->warn( "calling callback ($onWhat, $state, $event)"); 
        &$callback( $state, $event, @args );
    }
}

# ------------------------------------------------------------------------
# method: _attachCallback (private)
#
# add a callback. The callback will be called with the state, event
# and specified parameters.
#
# Parameters:
# $onWhat - 'onEntry', 'onExit'
# $state - name of the state to which attach the callback
# $event - name of the event for which the routine is called (undef = all events)
# $callback - routine reference
# ------------------------------------------------------------------------
sub _attachCallback {
    my $Self     = shift;
    my $onWhat   = shift;
    my $state    = shift;
    my $event    = shift;
    my $callback = shift;
    
    my $strEvent = ($event) ? $event : "";
    my $strState = ($state) ? $state : "";
    my $strCallback = ($callback) ? $callback : "";
    $Self->info( "adding callback (" 
          . $onWhat . ', ' 
          . $strState . ', '
          . $strEvent . ', '
          . $strCallback
          . ')' );

    if ($onWhat eq 'onFinal') {
        $Self->{'callbacks'}->{$onWhat} = $state;
        return;   
    }
    $Self->existState($state, GROUP)
      or die "unknown state $state";
    if ( defined($event) ) {
        $Self->existEvent($event)
          or die "unknown event $event";
    }

    if ( defined($event) ) {
        $Self->{'callbacks'}->{$onWhat}->{$state}->{$event} = $callback;
    }
    else {
        $Self->{'callbacks'}->{$onWhat}->{$state}->{'_allEvents'} = $callback;
    }
}

# ------------------------------------------------------------------------
# method: attachEntryCallback
#
# add an entry callback. The callback will be called with the state, event
# and specified parameters.
#
# Parameters:
# $state - name of the state to which attach the callback
# $event - name of the event for which the routine is called (undef = all events)
# $callback - routine reference
# ------------------------------------------------------------------------
sub attachEntryCallback {
    my $Self = shift;
    $Self->_attachCallback( 'onEntry', @_ );
}

# ------------------------------------------------------------------------
# method: attachFinalCallback
#
# Final callbacks are called while transiting from a non final to a final
# state.
#
# Parameters:
# $callback - routine reference
# ------------------------------------------------------------------------
sub attachFinalCallback {
    my $Self = shift;
    $Self->_attachCallback( 'onFinal', @_ );
}

# ------------------------------------------------------------------------
# method: attachExitCallback
#
# add an exit callback. The callback will be called with the state, event
# and specified parameters.
#
# Parameters:
# $state - name of the state to which attach the callback
# $event - name of the event for which the routine is called (undef = all events)
# $callback - routine reference
# ------------------------------------------------------------------------
sub attachExitCallback {
    my $Self = shift;
    $Self->_attachCallback( 'onExit', @_ );
}

# ------------------------------------------------------------------------
# method: reset
#
# reset the SMA, set back the current state to the initial state
# ------------------------------------------------------------------------
sub reset {
    my ($Self) = @_;
    
    $Self->info("reset");
    
    my $departure = $Self->{'current'};
    my $arrival = $Self->{'initial'};
    
    # disable all timers of the departure states
    my @exited = _subStates ( $departure);
    foreach my $dep ( @exited ) {
        # we do not disable timers when we stay on the same state to not reset
        # not yet expired timeouts. SMA uses periodic timers.
        if ( exists( $Self->{'timers'}->{$dep} ) ) {
            foreach my $t ( @{ $Self->{'timers'}->{$dep} } ) {
                $Self->trace("$dep disabling timer");
                $t->cancel();
            }
        }
    }

    # set current state
    $Self->{'current'} = $arrival;
    
    # and enable the timers of the arrival states
    my @entered = _subStates( $arrival );
    foreach my $arr ( @entered ) {
        if ( exists( $Self->{'timers'}->{$arr} ) ) {
            foreach my $t ( @{ $Self->{'timers'}->{$arr} } ) {
                $Self->trace("$arr starting timer");
                $t->start();
            }
        }
    }
}

# ------------------------------------------------------------------------
# method: setFinal
#
# set or reset  a state as final.
#
# Parameters:
# state - name of the state
# final - boolean value
# ------------------------------------------------------------------------
sub setFinal {
    my ( $Self, $state, $final ) = @_;

    $Self->existState($state) or die "Unknown state $state";
    if ( defined($final) ) {
        if ($final) {
            $Self->{'finals'}->{$state} = 1;
        }
        else {
            delete( $Self->{'finals'}->{$state} );
        }
    }
    else {
        $Self->{'finals'}->{$state} = 1;
    }
}

# ------------------------------------------------------------------------
# method: isFinal
#
# true for final states.
#
# Parameters:
# state - name of the state
# Return: boolean value
# ------------------------------------------------------------------------
sub isFinal {
    my ( $Self, $state ) = @_;

    $Self->existState($state) or die "Unknown state $state";
    return $Self->{'finals'}->{$state};
}

# ------------------------------------------------------------------------
# method: completed
#
# Return: true when the current state of the automatom is final
# ------------------------------------------------------------------------
sub completed {
    my ($Self) = @_;

    return $Self->isFinal( $Self->{'current'} );
}

# ------------------------------------------------------------------------
# method: addTimeout
#
# Add a timeout to a state. Timeouts are automatically activated
# on state entry and disabled on state exit. It is a guarantee that
# a timeout will not be triggered when the SMA is not in a state in which
# it can be treated. When triggered the timeout just generates the associated
# event. It is up to the designed to determine if he wants to stay in the
# same state or go elsewhere.
#
# There is a check than a transition is defined for the associated event
# in the state, so you are sure that if the timeout expires a transition
# exist to treat it.
#
# Note that the approach garantees that the transition is
# defined when the timeout expires, and its disables for you all timeouts
# associated to a state when you leave it.
#
# I was not sure about the possibility to attach timeout to all states
# (accept undef as a valid state). In fact it will better supported
# with nested states.
#
# Parameters:
# $state - name of the state to which to attach the timeout
# $event - name of the event generated on timeout
# $duration - relative time in second
# $periodic - auto restarted timeout.
# ------------------------------------------------------------------------
sub addTimeout {
    my ( $Self, $state, $event, $duration, $periodic ) = @_;

    $Self->fatal(
        'addTimeout (' . $state . ', ' . $event . ', ' . $duration . ')' );

    # check exitence of state, event and transition
    $Self->existState( $state, GROUP ) or die "State $state does not exist";
    $Self->existEvent($event) or die "event $event does not exist";
    exists( $Self->{'transitions'}->{$state}->{$event} )
      or die "transition must be defined for event " 
      . $event
      . ' from state '
      . $state
      . ' to attach a timer';

    # create a timer
    my $tm = new Events::SMATimer(
        sma      => $Self,
        event    => $event,
        delay    => $duration,
        periodic => $periodic,
        name     => "timer: state=$state delay=$duration"
    );

    # add the timer to the list associated with the state
    if ( !exists( $Self->{'timers'}->{$state} ) ) {
        $Self->{'timers'}->{$state} = [];
    }
    push( @{ $Self->{'timers'}->{$state} }, $tm );
  
    # start the timers of the current state (and groups)
    if ($Self->{'current'} =~ /$state/) {
        $tm->start();
    }
}

# ------------------------------------------------------------------------
# method: automatic Transition
#
# combine a addTransition and an addTimeout
#
# Parameters:
# departure - departure state
# event - triggering event
# arrival - arrival state
# duration - relative time in second
# ------------------------------------------------------------------------
sub automaticTransition {
    my ( $Self, $departure, $event, $arrival, $duration ) = @_;

    $Self->addTransition( $departure, $event, $arrival );
    $Self->addTimeout( $departure, $event, $duration );
}

# ------------------------------------------------------------------------
# method: dump
#
# Prints the object state. Full version for debug.
# ------------------------------------------------------------------------
sub dump {
    my ($Self) = @_;

    print Dumper($Self), "\n";
}

# ------------------------------------------------------------------------
# method: history
#
# return the trace of all transitions
# ------------------------------------------------------------------------
sub history {
    my ($Self) = @_;

    return "Transition log:\n" . $_[0]->{'history'};
}

# ------------------------------------------------------------------------
# method: image
#
# Return: a string containing an object description
# ------------------------------------------------------------------------
sub image {
    my ($Self) = @_;

    my $res = '';

    my @states = @{ $Self->states() };
    $res .= "initial = ";
    if ( exists( $Self->{'initial'} ) ) {
        $res .= $Self->{'initial'};
    }
    $res .= "\ncurrent = ";
    if ( exists( $Self->{'current'} ) ) {
        $res .= $Self->{'current'};
    }

    $res .= "\nStates = ";
    foreach my $v (@states) {
        if ( $Self->isFinal($v) ) {
            $res .= "(" . $v . "), ";
        }
        else {
            $res .= $v . ", ";
        }
    }
    $res .= "\n";

    $res .= "Events = ";
    foreach my $e ( @{ $Self->{'events'} } ) {
        $res .= $e . ", ";
    }
    $res .= "\n";

    $res .= "transitions = \n";
    foreach my $departure (keys(%{$Self->{'transitions'}})) {
        foreach my $event (keys(%{$Self->{'transitions'}->{$departure}})) {
                my $arrival = $Self->{'transitions'}->{$departure}->{$event};
                $res .= "\t" . $departure . " --(" . $event . ")--> " . $arrival . "\n";
        }
    }
    return $res;
}

# ------------------------------------------------------------------------
# method: check
#
# Check that an automatom as the following properties
#
# TODO: Check that all states are reachable
# ------------------------------------------------------------------------
sub check {
    my ($Self) = @_;

    exists( $Self->{'initial'} ) or die 'no initial state';
    exists( $Self->{'current'} ) or die 'no current state';

    $Self->existState( $Self->{'initial'} ) or die 'unknow initial state';
    $Self->existState( $Self->{'current'} ) or die 'unknow current state';

    my $final_nb = 0;
    my @states   = @{ $Self->states() };

    foreach my $s (@states) {
        if ( $Self->isFinal($s) ) {
            $final_nb++;
        }
        else {
            exists( $Self->{'transitions'}->{$s} )
              or die "$s is not terminal and has no exit transition";
        }
    }

    ( $final_nb > 0 ) or die "no final states";

    # Check that all referenced events and states exist
    foreach my $transition ( keys( %{ $Self->{'transitions'} } ) ) {
        $Self->existState( $transition, GROUP )
          or die "unknow state $transition as transition departure";
        foreach my $event ( keys( %{ $Self->{'transitions'}->{$transition} } ) )
        {
            $Self->existEvent($event)
              or die "unknow event $event in transition definition";
            my $arrival = $Self->{'transitions'}->{$transition}->{$event};
            $Self->existState($arrival)
              or die "unknow state $arrival as transition arrival";
        }
    }
}

1;
