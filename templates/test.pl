# ------------------------------------------------------------------------
# Title:  Component Test Template
#
# Source - <file:../test.pl.html>
# Version - 1.0
#
# Abstract:
#
#    This is a component test template. It derives from the <Test> class.
#    You can notice how the test description is embedeed in comments
#    to have the test sheets extracted directly from the test with
#    *NaturalDocs*
#
#    See the <Test> and <Script> module documentation for the detail
#    of accepted options.
#
# Test Purpose:
#
#    This test checks the Test class and provides an example
#    to generate tests.
#
# Execution:
#
#    > perl test.pl -v -skip setup
#
# Acceptation criteria:
#
#    It is a self-reporting tests which uses the Test::More Perl
#    module for reporting. If the test fails it is reported on STDOUT.
#
# Usage:
# (Start code)
# Test template.
#
# usage: perl test.pl [options]
#        -verbose         flag    switch on verbose mode.
#        -fail            flag    set to emulate failure
#        -match           array   Keywords, execute the matching parts, (default all)
#        -requirements    array   Requirements covered by the test
#        -directory       string  Logs and result directory
#        -outputDirectory string  directory for outputs
#        -memory          flag    checks the memory usage.
#        -synopsis        string  test short description
#        -skip            array   Keyword, skip the matching parts (default none)
#        -pid             string  pid of the process to monitor
#        -iteration       string  number of test iteration.
#        -help            flag    display the online help.
#        -testId          string  test identificator. (default = script basename)
#        -performance     flag    displays execution time.
#
# Exemple:
#
#    perl test.pl -help
#
# (end)
#
# Output:
# Example of success.
# (start code)
# 2009/07/03 15:02:25 WARN Tests.Checks : PASSED Subtest 1
# 2009/07/03 15:02:25 WARN Tests.Checks : PASSED Subtest 2, fails when required by parameter
# 2009/07/03 15:02:25 WARN Tests.Checks : PASSED Highwatermark =  1440 at 33%
# 2009/07/03 15:02:25 WARN Tests.Checks : PASSED TOTO, success=7, failures=0
# (end)
# ------------------------------------------------------------------------
# To customize: replace the package name
package ComponentTest;

use strict;
use lib "$ENV{'FTF'}/lib";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Test;

$VERSION = 1;
@ISA     = qw(Test);

# To customize: add your own libraries
use Data::Dumper;
use ExecutionContext;
use ScriptConfiguration;

# ------------------------------------------------------------------------
# method: subtest_1
#
# first subtest
# ------------------------------------------------------------------------
sub subtest_1 {
    my $Self = shift;

    # First subtest
    $Self->ok( 1, "Subtest 1" );
}

# ------------------------------------------------------------------------
# method: subtest_2
#
# second subtest
# ------------------------------------------------------------------------
sub subtest_2 {
    my $Self      = shift;
    my $must_fail = $Self->{'config'}->value('fail');

    # Second subtest
    $Self->warn("Subsequent method may fail");
    $Self->ok( !$must_fail, "Subtest 2, fails when required by parameter" );
    if ($must_fail) {
        $Self->trace("log at the TRACE level");
        $Self->debug("log at the DEBUG level");
        $Self->info("log at the INFO level");
        $Self->warn("log at the WARN level");
        $Self->error("log at the ERROR level");
        $Self->fatal("log at the FATAL level");
    }

    eval {
        die "exception raised";
        $Self->ok( 0, "expected error not reported" );
    };
    if ($@) {
        $Self->ok( 1, "expected error correctly reported: $@" );
    }
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
    if ( $Self->{'scenario'} ) {
        my $scen = $Self->{'scenario'};
        ( -f $scen ) or die "scenario $scen not found";

        my $cmd = `cat $scen`;
        eval $cmd;
        if ($@) {
            $Self->failed("Error in scenario $scen: " . $@);
        }
    }
    else {
        $Self->info("TestMain");

        $Self->subtest_1();
        $Self->subtest_2();
    }
}

# ------------------------------------------------------------------------
# On line help and options.
# The full online help is the catenation of the header,
# the parameters description and the footer. Parameters description
#  is automatically computed.

# my $config     = new ScriptConfiguration('scheme'     => TEST);

# To customize: you can remove help specification, remove the
# configuration file, remove additional parameters and even remove
# everything related to configuration.
my $help_header = '
Test template. 

usage: perl test.pl [options]';

my $help_footer = "
Exemple:

    perl test.pl -help
    perl test.pl -iter 2 -scen scen1.scen
";

# If you specify a configuration file, it must exist.
my $configFile = ExecutionContext::configFile();
my $config     = new ScriptConfiguration(
    'header'     => $help_header,
    'footer'     => $help_footer,
    'scheme'     => TEST,
    'parameters' => {
        fail => {
            type        => "flag",
            description => "set to emulate failure",
            default     => 0
        },
        scenario => {
            type        => "string",
            description => "test scenario (subscript)",
            default     => ""
        }
    },
#    'configFile' => $configFile
);

# Variable: test
# To customize: replace by your package name
my $test = new ComponentTest(
    testId       => $config->value('testId'),
    synopsis     => $config->value("synopsis"),
    scenario     => $config->value("scenario"),
    config       => $config,
    keywords     => [ 'Unix', 'AIX' ],
    requirements => [ 'REQ4', 'REQ6' ],
    loggerName   => "Test",
    iteration    => $config->value('iteration'),
    match        => $config->value('match'),
    skip         => $config->value('skip'),
    memory       => $config->value('memory'),
    pid          => $config->value('pid'),
    performance  => $config->value('performance')
);

# Add additional requirements from CLI (remove if useless)
$test->requirements( $config->value('requirements') );
$test->requirements( ['REQ4'] );

# To customize: replace by your test documentation
$test->doc("TestId = $test->{'testId'}");
$test->doc("This test checks that the software works.");
$test->doc("");
$test->doc("The programs is started, then several data sets are submitted.");
$test->doc("Each outputs are checks for conformity.");
$test->doc("");
$test->doc("AcceptationCriteria, this is a self reporting test");
$test->doc("");

exit($test->run());

