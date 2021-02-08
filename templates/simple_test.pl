#!/usr/bin/perl

# ------------------------------------------------------------------------
# Title: Simple Test Template
#
# Source - <file:../simple_test.pl.html>
#
# Abstract:
#
#    Example of test script.
#    
# ------------------------------------------------------------------------
# Perl pragmas
use strict;
use warnings;
use 5.010;

# CPAN modules
use Getopt::Long;
use Log::Log4perl qw(:easy);

# Tool kit modules
use lib "$ENV{'FTF'}/lib";
use MTest;

# Script name
my $name = $0;
Log::Log4perl::init("$ENV{'FTF'}/conf/log4perl.conf");
my $log = Log::Log4perl->get_logger('Test'); # log4perl.logger.script

# Default command line parameters
my $help;
my $iteration = 1;
my $fail;
my $testId = "test_1";
my $scenario = $testId;
my @match = ();
my @skyp = ();
my $memory;
my $performance;

# Command line arguments
my %arguments = (
	"help"        => \$help,      # flag
	"iteration=i" => \$iteration,
	"fail"        => \$fail,
	"testId=s"    => \$testId,
	"scenario=s"  => \$scenario,
	"memory"      => \$memory,
	"performance" => \$performance,
	"match=s"     => \@match,
	"skyp=s"      => \@skyp
);

# ------------------------------------------------------------------------
# routine: usage
# ------------------------------------------------------------------------
sub usage () {
	say "
Test template. 

usage: perl $name [options]

     Options:
       -help            brief help message
       -iteration n     number of iteration for the test (default=1)
       -fail            emulate a failed test
       -id name         test id (default=test_1)
       -scenario name   name of the scenario to execute (default = \"\")
       -memory          activate memory leaks checks
       -performance     measure the time for each iteration
       
Exemple:

    perl $name.pl -help
    perl $name.pl -pattern 'sub' script.pl
";
	exit();
}

# log invocation command
$log->info($0 . " " . join(" ",@ARGV));

# parse the CLI
my $result = GetOptions(%arguments);
if ($help) {
     # print usage and exit
	usage();
}

my $test = new MTest(testId => $testId, 
    scenario => $scenario,
    logName => "Test",
    junit => $scenario . ".xml");

# ------------------------------------------------------------------------
# method: SetUp
#
# Test preparation, empty when nothing to do. Can be skipped if the
# test context can be setup for several test executions.
# ------------------------------------------------------------------------
sub SetUp {
    $test->start();
}

# ------------------------------------------------------------------------
# method: TestMain
#
# Test main routine. It is this method which is executed several times
# when the *-iteration* parameter is more than 1.
# ------------------------------------------------------------------------
sub TestMain {
    $test->iteration_start();
    $test->ok( 1, "Subtest 1" );
    if ($fail) {
        $test->ok( 0, "Subtest 2" );
    } else {
        $test->ok( 1, "Subtest 2" );
    }
    $test->iteration_stop();
}

# ------------------------------------------------------------------------
# method: CleanUp
#
# Test cleanup, for example delete all the test generated files.
# ------------------------------------------------------------------------
sub CleanUp {
    $test->stop();
}

# run the test
SetUp();
for (my $i = 0; $i < $iteration; $i++) {
    TestMain();
}
CleanUp();
$test->result();

# ------------------------------------------------------------------------
# routine: logFilename
#
# This routine is used in the log4perl configuration file
# It must stay in the global name space. If this version does not
# work for you just call it with the name you want.
#
# Return:
#     - The log file name.
# ------------------------------------------------------------------------
sub logFilename {
    return $0 . ".log";
}
