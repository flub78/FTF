# ------------------------------------------------------------------------
# Title:  Events
#
# File - Events.pl
# Version - 1.0
#
# Abstract:
#
#    Test for the Events toolbox.
# ------------------------------------------------------------------------
package EventsTest;

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

use Events::Server;
# use Events::EchoClient;
use Events::Timer;
use Events::File;
use Events::Socket;
use Events::Console;
use Events::Console;
use Events::UDPReader;
use Events::Program;
use Events::EventsManager;

my $alarm3;


my $cnt = 0;
sub incCnt {
	print "# Hello, how are you\n";
	$cnt++;	
}

# ------------------------------------------------------------------------
# method: after
#
# after subtest
# ------------------------------------------------------------------------
sub afterTest {
    my $Self = shift;

    my $start = time();
    my $startCnt = 0;
    
    # simple wait
    after (3);
    my $current = time;
    ok (time >= $start + 2, "after has waited long enough, start=$start, current=$current");
    ok (time < $start + 4, "after has not waited for too long, start=$start, current=$current");
    
    # declare a routine to be called later
    $start = time();
	after (3, \&incCnt);
    $current = time;
    ok (time <= $start + 1, "after immediate return, start=$start, current=$current");
    ok ($cnt == $startCnt, "after delayed invocation");
    
    # check after the timeout
	after(5);
	$current = time;
    ok (time >= $start + 4, "after with param has waited long enough, start=$start, current=$current");
    ok (time < $start + 6, "after with param has not waited for too long, start=$start, current=$current");
    ok ($cnt == $startCnt + 1, "after has activated the parameter routine");
}

# ------------------------------------------------------------------------
# method: timers
#
# second subtest
# ------------------------------------------------------------------------
sub timers {
    my $Self = shift;

    my $alarm1 = new Events::Timer( name => "Timer1" );
    ok( $alarm1, "Timer creation" );

    my $alarm2 = new Events::Timer( name => "Timer2" );
    $alarm3 = new Events::Timer( name => "Timer3" );
    $alarm1->start(5);
    $alarm2->start( 2,   5 );
    $alarm3->start( 1.5, 5 );
    $alarm3->cancel();
    after( 12, \&stopLoop );
    eventLoop();

    is( $alarm1->timeoutNumber(),
        1, "number of activations of a one shot timer" );
    is( $alarm2->timeoutNumber(),
        5, "number of activations of a multiple shots timer: " .  $alarm2->timeoutNumber());
    is( $alarm3->timeoutNumber(),
        0, "number of activations of a cancelled timer: " . $alarm3->timeoutNumber() );
}

# ------------------------------------------------------------------------
# method: files
#
# Checks Events::File in and out.
# ------------------------------------------------------------------------
sub files {
    my $Self = shift;

    my $file1 = new Events::File();
    my $file2 = new Events::File();
    ok( $file1, "File handler creation" );

    $file1->open( "fileToRead",  "<" );
    $file2->open( "fileToWrite", ">" );

    $file1->addDestination($file2);

    after( 4, \&stopLoop );
    eventLoop();
    
    $file1->close();
    $file2->close();
    is( $file1->bytesReceived(), 71777, "number of bytes read from file" );
    is( $file2->bytesWritten(), 71777, "number of bytes written to file" );
}


# ------------------------------------------------------------------------
# method: program
# ------------------------------------------------------------------------
sub program {
    my $Self = shift;

    my $pgm = new Events::Program('cmd' => 'find .');
    my $console = new Events::Console();
    
    ok( $pgm, "Program creation" );
    
    $pgm->addDestination($console);
    
    # $pgm->send("ls\n");
    after( 4, \&stopLoop );
    eventLoop();
    
    $pgm->close();
}

# ------------------------------------------------------------------------
# method: cat
#
# Tests Events::File in read mode and Events::Console in output
# ------------------------------------------------------------------------
sub cat {
    my $Self = shift;

    my $file1 = new Events::File();
    my $console = new Events::Console();
    ok( $file1, "File handler creation" );
    
    $file1->open( "fileToRead",  "<" );

    $file1->addDestination($console);
        
    after( 4, \&stopLoop );
    eventLoop();
    
    $file1->close();
}

# ------------------------------------------------------------------------
# method: cat
#
# Tests Events::File in read mode and Events::Console in output
# ------------------------------------------------------------------------
sub console {
    my $Self = shift;

    my $console = new Events::Console();
    
    $console->send("Hello\n");    
    $console->send("What is your name ?");
    $console->send("\n");    
    after( 20, \&stopLoop );
    eventLoop();
}

# ------------------------------------------------------------------------
# method: udp
#
# Abstact:  Events::UDP in and out, Events::File in and out.
#
#    - read a file
#    - create an UDP listener
#    - broadcast it on UDP
#    - copy the UDP received data into another file
# ------------------------------------------------------------------------
sub udp {
    my $Self = shift;

    my $file1 = new Events::File();
    my $file2 = new Events::File();

    $file1->open( "fileToRead",  "<" );
    $file2->open( "fileFromUdp", ">" );
    
    my $udpBroadcast = new Events::Socket();
    $udpBroadcast->connect('localhost', 12345, 'udp');

    my $udpReader = new Events::UDPReader(
        port => 12345
    );

    $file1->addDestination($udpBroadcast);
    $udpReader->addDestination($file2);

    after( 5, \&stopLoop );
    eventLoop();
    
    $file1->close();
    $file2->close();
    ok( $file2->bytesWritten() > (71777 * 0.9), "number of bytes transmitted by UDP" );
}

sub timer1 {
	print "timer1\n";
	signal("timer1", "data1");
}

sub timer2 {
    print "timer2\n";
    signal("timer2");
}

sub timer3 {
    signal("timer1", "three");
}

# ------------------------------------------------------------------------
# method: tcp
#
# Abstact:  TCP/IP client and servers
#
#    - create a echo server
#    - create a echo client
# ------------------------------------------------------------------------
sub tcp {
    my $Self = shift;


    ok( 0, "TCP/IP connection" );
}

# ------------------------------------------------------------------------
# method: user_events
# ------------------------------------------------------------------------
sub user_events {
    my $Self = shift;

    print "# user events test\n";
    my $start = time();
    my $res = wait_for ("ever", 3.0);
    
    is ($res, undef, "wait_for returns undef on timeout");
    my $delta = time() - $start;
    ok ($delta >= 3, "wait_for blocked for the timeout duration");
    ok ($delta < 5, "but no more");
    
    after( 5, \&timer2 );
    after( 3, \&timer1 );
    
    my $res = wait_for ("timer2");
    is ($res, "timer2", "wait_for returns the signaled event");
    my $res = wait_for ("timer1");
    is ($res, "data1", "wait_for returns the event data");
    
    # push two signals to check that they are not overwritten
    signal("timer1", "one");
    signal("timer1", "two");
    after( 3, \&timer3 );
    for (my $i = 0; $i < 3; $i++) {
        print wait_for("timer1"), "\n";
    }
}

# ------------------------------------------------------------------------
# method: TestMain
#
# Test main routine. It is this method which is executed several times
# when the *-iteration* parameter is more than 1.
# ------------------------------------------------------------------------
sub TestMain {
    my $Self = shift;
    $Self->info("TestMain");

    $Self->tcp();
    $Self->user_events();
    return;
	$Self->afterTest();
    $Self->timers();
    $Self->program();
    $Self->console();
    $Self->cat();
    $Self->files();
    $Self->udp();
 }

# ------------------------------------------------------------------------
my $config     = new ScriptConfiguration(
    'scheme'     => TEST,
);

# Variable: test
# my Test local instance.
my $test = new EventsTest();
$test->run();

