# ------------------------------------------------------------------------
# Title:  Installation Test
#
# Version - 1.0
#
# Abstract:
#
#    Installation test. The test checks that the Perl modules most commonly 
#    used by the toolbox are installed. If your environment is correct
#    this test should print PASSED.
#
# Execution:
#
#    > perl installation.t
# ------------------------------------------------------------------------
package Installation;

use strict;
use lib "$ENV{'FTF'}/lib";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Test;

$VERSION = 1;
@ISA     = qw(Test);

# Test::More is only used to test Perl modules.
use Test::More qw( no_plan ), import => ['!ok', '!is'];
use Data::Dumper;
use ExecutionContext;
use ScriptConfiguration;

# ------------------------------------------------------------------------
# method: TestMain
#
# Test main routine. It is this method which is executed several times
# when the *-iteration* parameter is more than 1.
# ------------------------------------------------------------------------
sub TestMain {
    my $Self = shift;
    $Self->ok(require XML::Twig, "XML::Twig installed");
    $Self->ok(require XML::Writer, "XML::Writer installed");
    $Self->ok(require IO::File, "IO::File installed");
    $Self->ok(require DBI, "DBI installed");
    $Self->ok(require Carp::Assert, "Assertion management");
    $Self->ok(require File::Remote, "File::Remote installed");
    $Self->ok(require Log::Log4perl, "Log::Log4perl installed");
    $Self->ok(require Class::Singleton, "Class::Singleton installed");
    $Self->ok(require Event, "Event installed");
        
    $Self->ok(1, "installation succesful");
}

# ------------------------------------------------------------------------
my $config     = new ScriptConfiguration(
    'scheme'     => TEST,
);

# Variable: test
my $test = new Installation(
    testId       => $config->value('testId'),
    synopsis     => "Test synopsis",
    config       => $config,
    loggerName   => 'Test',
    iteration    => $config->value('iteration'),
    memory       => $config->value('memory'),
    pid          => $config->value('pid'),
    performance  => $config->value('performance'),
    useTestMore  => !$config->value('testId')    
);

$test->doc("TestId = $test->{'testId'}");
$test->doc("This test checks that toolbox installation");
$test->run();

