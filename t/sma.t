#!/usr/local/bin/perl -w
# ------------------------------------------------------------------------
# Title:  TestSMA
#
# File - TestSMA.pl
# Version - 1.0
#
# Abstract:
#
#    SMA unitary test.
# ------------------------------------------------------------------------
package TestSMA;

use strict;
use lib "$ENV{'FTF'}/lib";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Test;

$VERSION = 1;
@ISA     = qw(Test);

# Test::More is only used to test Perl modules.
use Test::More qw( no_plan );
use Data::Dumper;
use ExecutionContext;
use ScriptConfiguration;

use Events::EventsManager;
use Events::SMA;

my $entryCB = 0;
my $exitCB  = 0;

# ------------------------------------------------------------------------
# method: entryCallback
#
# Routine called on state entry
# ------------------------------------------------------------------------
sub entryCallback {
    my $state = shift;
    my $event = shift;
    my $test  = shift;
    my $sma   = shift;
    my @args  = @_;

    $entryCB++;
    if ($test) {
        print(
            "entryCallback: state=" . $state . " event=" . $event . "\n" );
        foreach my $arg (@args) {
            print("\targ = $arg\n");
        }
    }
}

# ------------------------------------------------------------------------
# method: exitCallback
#
# Routine called on state exit
# ------------------------------------------------------------------------
sub exitCallback {
    my $state = shift;
    my $event = shift;
    my $test  = shift;
    my $sma   = shift;
    my @args  = @_;

    $exitCB++;
    if ($test) {
        print(
            "exitCallback: state=" . $state . " event=" . $event . "\n" );
        foreach my $arg (@args) {
            print("\targ = $arg\n");
        }
    }
}

my $counter = 2;

# ------------------------------------------------------------------------
# method: terminalCallback
#
# Callback called on entry of terminal callbak
# ------------------------------------------------------------------------
sub terminalCallback {
    my ( $state, $event, $test, $sma ) = @_;

    if ($test) {
        $test->error(
            "terminalCallback: state=" . $state . " event=" . $event . "\n" );

        $counter--;

        if ( $counter > 0 ) {
            $test->error("first time in terminal state, try again\n");
            $sma->signal( 'B', $test, $sma );
        }
        else {
            $test->error(" disabling event loop");
            stopLoop();
        }
    }
}

# ------------------------------------------------------------------------
# method: basic
#
# Test main routine. It is this method which is executed several times
# when the *-iteration* parameter is more than 1.
# ------------------------------------------------------------------------
sub basic {
    my $Self    = shift;
    
    $Self->info("TestMain");

    # Declarative part, let's build a SMA
    # -----------------------------------
    my $sma = new Events::SMA(
        states      => [ 'Initial', 'State1', 'State2', 'Terminal' ],
        events      => [ 'A',       'B',      'Error' ],
        initial     => 'Terminal',
        transitions => {
            'Initial' => { 'Start' => 'State1' },
            'State1'  => {
                'A' => 'State2',
                'B' => 'Terminal'
            }
        },
        finals => { 'Terminal' => 1 },
        record => 1
    );

    # attachEntryCallback (arrival, event , routine, params)
    $sma->attachEntryCallback( 'State2', undef,
        sub { print "Global Entry callback\n" } );
    $sma->attachEntryCallback( 'State2', 'A', \&entryCallback );
    $sma->attachExitCallback( 'State2', undef, \&exitCallback );

    $sma->attachEntryCallback( 'Initial',  undef, \&entryCallback );
    $sma->attachEntryCallback( 'State1',   undef, \&entryCallback );
    $sma->attachEntryCallback( 'Terminal', undef, \&terminalCallback );

    $sma->attachExitCallback( 'Initial',  undef, \&exitCallback );
    $sma->attachExitCallback( 'State1',   undef, \&exitCallback );
    $sma->attachExitCallback( 'Terminal', undef, \&exitCallback );

    is( scalar( @{ $sma->states() } ), 4, "number of states after init" );
    is( scalar( @{ $sma->events() } ), 3, "number of events after init" );
    is( $sma->existState('State2'),    1, "check state existence" );
    is( $sma->existEvent('A'),         1, "check event existence" );
    is( $sma->existEvent('Timeout'),   0, "check event non existence" );

    $sma->addState('State3');
    $sma->attachEntryCallback( 'State3', undef, \&entryCallback );
    $sma->attachExitCallback( 'State3', undef, \&exitCallback );

    $sma->addEvent('Timeout');
    is( scalar( @{ $sma->states() } ),
        5, "number of states after add a new state" );

    $sma->addState('State2');
    is( scalar( @{ $sma->states() } ),
        5, "number of states after erroneous addition a new state" );

    eval {
        $sma->initial('toto');
        ok( 0,
            "Error not detected during setting of initial to an unknown state"
        );
    };

    $sma->initial('Initial');

    eval { $sma->addTransition( 'Initial', 'Start', 'State1' ); };
    $sma->addEvent('Start');
    $sma->addTransition( 'Initial', 'Start', 'State1' );

    $sma->addTransition( 'State3',   'Timeout', 'State3' );
    $sma->addTransition( 'State3',   'Error',   'Terminal' );
    $sma->addTransition( 'Terminal', 'B',       'State3' );

    # attach some timers
    $sma->addTimeout( 'State3', 'Timeout', 0.5 );
    $sma->addTimeout( 'State3', 'Error',   2.0 );
return;
    # Dynamic part, lets trigger events.
    # ----------------------------------

    is( $sma->current(), 'Initial', 'Initial current state' );
    eval {
        is( $sma->signal( 'Stop', $Self, $sma ),
            'State1', 'Unknown event for transition' );
        ok( 0, "Error not detected, signaling of an unknown event" );
    };

    my $current;
    $entryCB = 0;
    $exitCB  = 0;
    is( $current = $sma->signal( 'Start', $Self, $sma ),
        'State1', 'transition 1' );

    is( $sma->current(), $current, 'Current after transition' );
    is( $entryCB,        1,        "entry callback has been invoked" );
    is( $exitCB,         1,        "exit callback has been invoked" );

    is( $sma->signal( 'A', $Self, $sma ), 'State2', 'transition 2' );

    eval {
        is( $current = $sma->signal( 'Start', $Self, $sma ),
            '---', 'illegal transition' );
        ok( 0, "illegal transition not detected" );
    };

    $sma->setFinal('State3');

    is( $sma->completed(), undef, 'not completed' );
    $sma->addTransition( 'State2', 'B', 'State3' );
    $sma->signal( 'B', $Self, $sma );
    is( $sma->completed(), 1, 'completed' );

    print $sma->image();
    if ($Self->{verbose}) {
        $sma->dump();
    }

    eventLoop();
    print $sma->history();
}

my $cnt = 0;

# ------------------------------------------------------------------------
# method: tick
#
# Routine called on state entry
# ------------------------------------------------------------------------
sub tic {
    my ( $state, $event, $Self, $sma ) = @_;
    $cnt++;

    if ( $cnt % 2 ) {
        print "tic, $cnt\n";
    }
    else {
        print "tac, $cnt\n";
    }
}

sub dring {
    my ( $state, $event, $Self, $sma ) = @_;
    print "Dring !!!!!!!!!!!!!!!!\n";
}

sub morning {
    my ( $state, $event, $Self, $sma ) = @_;
    print "time to wake up\n";
}

# ------------------------------------------------------------------------
# ------------------------------------------------------------------------
sub timeout {
    my $Self = shift;

    my $sma = new Events::SMA(
        states => [ 'A',    'End' ],
        events => [ 'tick', 'alarm', 'Error' ],
        transitions => {
            'A' => {
                'tick'  => 'A',
                'alarm' => 'End'
            }
        },
        initial => 'A',
        finals  => { 'End' => 1 },
        record  => 1
    );

    eval { $sma->check(); };
    print $sma->image(), "\n";
    $sma->check();

    $sma->attachEntryCallback( 'A',   undef,   \&tic, );
    $sma->attachEntryCallback( 'End', 'alarm', \&dring );
    $sma->attachFinalCallback( \&morning );

    # attach some timers
    $sma->addTimeout( 'A', 'tick', 1.0, Events::SMA::PERIODIC );
    $sma->addTimeout( 'A', 'alarm', 10.0 );

    # Event loop
    eventLoop();
    print $sma->history();
}

sub stateEntryCB {
    my $state = shift;
    my $event = shift;

    print "stateEntryCB ($state, $event) ", join (", ", @_), "\n";
}

sub stateExitCB {
    my $state = shift;
    my $event = shift;

    print "stateExitCB ($state, $event) ", join (", ", @_), "\n";
}

sub groupEntryCB {
    my $state = shift;
    my $event = shift;

    print "groupEntryCB ($state, $event) ", join (", ", @_), "\n";
}

sub groupExitCB {
    my $state = shift;
    my $event = shift;

    print "groupExitCB ($state, $event) ", join (", ", @_), "\n";
}

# ------------------------------------------------------------------------
# ------------------------------------------------------------------------
sub nested {
    my $Self = shift;

    my $sma = new Events::SMA( record => 1 );

    ok( $sma, "empty sma" );

    $sma->addState("test.phase1.A");
    $sma->addState("test.phase1.B");

    $sma->addState("test.phase2.T1");
    $sma->addState("test.phase2.T2");
    $sma->addState("test.phase2.T3");

    $sma->addState("End");

    $sma->initial("test.phase1.A");
    $sma->setFinal("End");

    $sma->addEvent("error");
    $sma->addEvent("timeout");
    $sma->addEvent("A");
    $sma->addEvent("B");

    $sma->addTransition( "test.phase1.A", "A", "test.phase1.B" );
    $sma->addTransition( "test.phase1.B", "A", "test.phase1.A" );

    $sma->addTransition( "test.phase2.T1", "B", "test.phase2.T2" );
    $sma->addTransition( "test.phase2.T2", "B", "test.phase2.T3" );
    $sma->addTransition( "test.phase2.T3", "B", "test.phase2.T1" );
        
    # now attach some global transitions
    # on error in phase1, go to phase2
    $sma->addTransition( "test.phase1", "timeout", "test.phase2.T1" );
    $sma->addTransition( "test.phase2", "timeout", "test.phase1.A" );

    $sma->automaticTransition( "test", "error", "End", 12 );

    print $sma->image(), "\n";

    $sma->attachEntryCallback("test.phase1.A", undef, \&stateEntryCB);
    $sma->attachEntryCallback("test.phase1.B", undef, \&stateEntryCB);
    $sma->attachEntryCallback("test.phase2.T1", undef, \&stateEntryCB);
    $sma->attachEntryCallback("test.phase2.T2", undef, \&stateEntryCB);
    $sma->attachEntryCallback("test.phase2.T3", undef, \&stateEntryCB);

    $sma->attachEntryCallback("test.phase1", undef, \&groupEntryCB);
    $sma->attachEntryCallback("test.phase2", undef, \&groupEntryCB);

    # exit callbacks
    $sma->attachExitCallback("test.phase1.A", undef, \&stateExitCB);
    $sma->attachExitCallback("test.phase1.B", undef, \&stateExitCB);
    $sma->attachExitCallback("test.phase2.T1", undef, \&stateExitCB);
    $sma->attachExitCallback("test.phase2.T2", undef, \&stateExitCB);
    $sma->attachExitCallback("test.phase2.T3", undef, \&stateExitCB);

    $sma->attachExitCallback("test.phase1", undef, \&groupExitCB);
    $sma->attachExitCallback("test.phase2", undef, \&groupExitCB);

    # lets fire some transition
    $sma->addTimeout("test.phase1.A", "A", 1, Events::SMA::PERIODIC);   
    $sma->addTimeout("test.phase1.B", "A", 1, Events::SMA::PERIODIC);   

    $sma->addTimeout("test.phase2.T1", "B", 1, Events::SMA::PERIODIC);  
    $sma->addTimeout("test.phase2.T2", "B", 1, Events::SMA::PERIODIC);  
    $sma->addTimeout("test.phase2.T3", "B", 1, Events::SMA::PERIODIC);  

    $sma->addTimeout("test.phase1", "timeout", 5, Events::SMA::PERIODIC);   
    $sma->addTimeout("test.phase2", "timeout", 5, Events::SMA::PERIODIC);
    
    $sma->attachFinalCallback(\&stopLoop);
    
    $sma->check();
    
    eventLoop();
       
    print $sma->history();

}

# ------------------------------------------------------------------------
# method: TestMain
#
# Test main routine. It is this method which is executed several times
# when the *-iteration* parameter is more than 1.
# ------------------------------------------------------------------------
sub TestMain {
    my $Self = shift;

    $Self->basic();
    $Self->timeout();
    $Self->nested();
}

# ------------------------------------------------------------------------

# my Test local instance.
my $config     = new ScriptConfiguration('scheme'     => TEST);

my $test = new TestSMA(verbose => $config->value('verbose'));
$test->run();

