# ------------------------------------------------------------------------
# Title:  TestTemplate
#
# Source - <file:../TestTemplate.pl.html>
# Version - 1.0
#
# Abstract:
#
#    Test result parser
#
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

use TCL::TestResultParser;

# To customize: adapt the online help
my $usage = "";
my $footer = "";

# Variable: OptionSet
#
# Additional options not already declared by Test.pm
# Look for existing parameters in the <TestTools::Test> documentation.
# To customize: replace and add your own parameters
my %OptionSet = (
    fail => {
        type        => "flag",
        description => "set to emulate failure",
        default     => 0
    },
);


# ------------------------------------------------------------------------
# method: subtest_1
#
# first subtest
# ------------------------------------------------------------------------
sub subtest_1 {
    my $Self = shift;

    my $res = new TCL::TestResultParser (filename => 'TEST1.log');
    
    ok ($res, "parser creation");
    
    print join (", ", $res->counter_list()), "\n";
    print join (", ", $res->table_list(1)), "\n";
    foreach my $tbl ($res->table_list(1)) {
        print "\ntable $tbl (";
        print scalar($res->table_columns($tbl));
        print " x ";
        print $res->table_size($tbl);
        print ")\n";
        
        print join (" | ", $res->table_columns($tbl)), "\n";
        
        for (my $line = 0; $line < $res->table_size($tbl); $line++) {
            foreach my $col ($res->table_columns($tbl)) {
                print $res->table_value($tbl, $col, $line), " | ";
            }
            print "\n";
        }
    }
}

# ------------------------------------------------------------------------
# method: subtest_2
#
# second subtest
# ------------------------------------------------------------------------
sub subtest_2 {
    my $Self      = shift;
    my $must_fail = ( TestTools::Conf::ScriptConfig::GetOption('fail') );


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

    $Self->subtest_1();
    $Self->subtest_2();
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
$test->requirements(TestTools::Conf::ScriptConfig::GetOption('requirements'));

# To customize: replace by your test documentation
$test->doc( "TestId = $testid");
$test->doc( "This test checks that the software works.");
$test->doc( "");
$test->doc( "The programs is started, then several data sets are submitted.");
$test->doc( "Each outputs are checks for conformity.");
$test->doc( "");
$test->doc( "AcceptationCriteria, this is a self reporting test");
$test->doc( "");

$test->requirements( [ 'REQ4' ] );

$test->run();


