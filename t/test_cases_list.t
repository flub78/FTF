# ------------------------------------------------------------------------
# Title:  TestTemplate
#
# Abstract:
#
#    Comma separated value file unit test
# ------------------------------------------------------------------------
# To customize: replace the package name
package TestTemplate;

use strict;
use lib "$ENV{'FTF'}/lib";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Test;

$VERSION = 1;
@ISA     = qw(Test);

# Test::More is only used to test Perl modules.
# use Test::More qw( no_plan );
use Data::Dumper;
use ExecutionContext;
use ScriptConfiguration;

use TCL::List;

# To customize: adapt the online help
my $usage = "";
my $footer = "";

# ------------------------------------------------------------------------
# method: subtest_1
#
# first subtest
# ------------------------------------------------------------------------
sub csv {
    my $Self = shift;

    # First subtest
    my $filename = "test_suite.csv";
    my $csv = new TCL::List (filename => $filename, titleLine => 4,
        testId => "TestId");
    my $val = "Another example of test suite;;;;;;;;;;;";
    $csv->line(0, $val);
    
    my $copie = $filename . ".cpy";
    unlink ($copie);
    ok (!(-f $copie), "copie erased");
    $csv->save($copie);
    ok ((-f $copie), "copie exist");
    
    # reload copie
    my $csv2 = new TCL::List (filename => $copie, titleLine => 4,
        testId => "TestId");
    is ($csv2->line(0), $val, "modified first line in copy");

    is ($csv->line(3), $csv2->line(3), "unmodified lines are equal");
    
    my $ln = $csv->lineNumber();
    is ($csv->line($ln), undef, "last line + 1");
    
    is ($csv2->titleLine(), 4, "titleLine");
    
    is (join (", ", $csv2->title()), "Engine, Scenario, TestId, Synopsis, output, fail, iteration, perf, memory, host, selected, requirements", "columnNames");
    
    is ($csv2->colNumber(), 12, "colNumber");
    is ($csv2->colName(0), "Engine", "colName[0]");
    is ($csv2->colName(11), "requirements", "colName[11]");
    is ($csv2->colName(12), undef, "colName[12]");
}

# ------------------------------------------------------------------------
# method: subtest_2
#
# second subtest
# ------------------------------------------------------------------------
sub tcl {
    my $Self      = shift;
    
    my $filename = "test_suite.csv";
    my $tcl = new TCL::List(
        filename => $filename,
        titleLine => 4,
        testId => "TestId",
        selector => "selected",
        synopsis => "Synopsis",
        column => ['Engine', 'Scenario'],
        parameter => ['TestId', 'output', 'iteration', 'host'],
        flag => ['fail', 'perf', 'memory'],
        csv => ['requirements']);

    ok( $tcl, "tcl creation" );
    is (join (", ", $tcl->allTests()), "TEST1, TEST2, TEST3, TEST4, TEST5, TEST6, TEST7, TEST8, TEST9, TEST10, TEST11, TEST12, TEST20, TEST21, TEST22", "Test list");
    is (join (", ", $tcl->selectedTests()), 'TEST1, TEST4, TEST9, TEST10, TEST21', "Selected test list");
    
    # Test tests
    is ($tcl->test('TEST1')->synopsis(), "T1 Smoke test check", "test synopsis");
    is ($tcl->test('TEST2')->testId(), "TEST2", "test testId");
    
    # print $tcl->dump(), "\n";
    $tcl->script();
}

# ------------------------------------------------------------------------
# method: TestMain
#
# Test main routine. It is this method which is executed several times
# when the *-iteration* parameter is more than 1.
# ------------------------------------------------------------------------
# To customize: replace the test main method
sub TestMain {
    my $Self = shift;
    $Self->info("TestMain");

    $Self->csv();
    $Self->tcl();
}

# ------------------------------------------------------------------------

# read CLI and configuration file
my @argv = @ARGV;
Initialize(TestTools::Script::configurationFilename(),
    \%OptionSet, TestTools::Test::optionSet());

# initilize logger configuration
main::setOutputDirectory (TestTools::Conf::ScriptConfig::GetOption('outputDirectory'));
my $testid = (TestTools::Conf::ScriptConfig::GetOption('testId')) ?
   TestTools::Conf::ScriptConfig::GetOption('testId') :
   TestTools::Script::basename();
main::setOutputBasename ($testid);


# Variable: test
# To customize: replace by your package name
my $test = new TestTemplate(
    keywords     => \@KEYWORDS,
    requirements => [ 'REQ4', 'REQ6' ],
    loggerName   => "Tests",
    argv => \@argv,
    testId => $testid
);

# To customize: replace by your test documentation
$test->doc( "TestId = $testid");
$test->doc( "Goals = This test checks that the software works.");
$test->doc( "");
$test->doc( "The programs is started, then several data sets are submitted.");
$test->doc( "Each output are checks for conformity.");
$test->doc( "");
$test->doc( "AcceptationCriteria = Self reporting test");
$test->doc( "");

$test->requirements( [ 'REQ4' ] );

$test->run();


