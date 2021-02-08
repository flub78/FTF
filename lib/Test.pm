# ----------------------------------------------------------------------------
# Title:  Class Test
#
# File - Test.pm
# Version - 1.0
#
# Abstract:
#
#       Root class for the framework test scripts. By deriving from this
#       class you will get the services from <Script> objects more
#       specific services.
#
#       The test class provides and equivalent mechanism to Test::More which uses
#       the logging mechanism to report results. It is recommended to use
#       Test::More for unit tests of Perl modules and the mechanism provided
#       by the class for externam components tests, Unix processes for example.
#
#       Several sub loggers are defined:
#       .Doc - to print test description
#       .Traces - for test execution traces
#       .Checks - to control the assertions on which success or failure of the test are based
#       .Counters - to report test numerical data
#       .IO - to log communication data
#
#       Example of test configuration file:
#       (Start code)
#       # ----------------------------------------------------------------
#       # log4perl.logger.Tests = ALL, Test
#       # log4perl.logger.Tests.Traces = ALL, Test, TestFile
#       log4perl.logger.Tests.Checks = INFO, Test, TestFile
#       # log4perl.logger.Tests.Doc = INFO, Test, TestFile
#       # log4perl.logger.Tests.Counters = INFO, Test, TestFile
#       # log4perl.logger.Tests.IO = INFO, Console, ContextFile
#       # ----------------------------------------------------------------
#       (end)
#
# Attributes:
#
#    Attributes can be provided as hash values to the constructor. If you do not
#    provide them reasonable defaults are provided.
#
#    testId      - the test identifier
#    synopsis    - a short test description
#    keywords    - the reference to a list of keywords, use for test selection
#    iteration   - number of time that the main loop is executed
#    memory      - tells your test that it should monitor memory usage
#    pid         - pid of pattern matching the process in 'ps' for memory monitoring
#    performance - tells the script that it should measure execution time
#    match       - if the test matchs the keywords it should be executed
#    skip        - if the test  matchs the keywords it must be skipped
#    requirments - a list of requirements for documentation
#
#    The test object support the concept of test categories, categories are defined
#    by keywords. The test execution can be controled according to its category.
#    The test or sub-test categories are compared to the values provided by the
#    match and skip configuration parameters, in order to determine if the test must
#    be executed or skipped.
#
#    That way it should be possible to run all the test that match a category, for example
#    all the tests for a given requirement and skip all the tests within another category,
#    for example to skip all interactive tests.
#
#    This test template has 3 steps :
#
#       SetUp           - Fulfill all the initialization of environment and checks needed
#                         before tests execution
#       Test execution  - it's a real test part. Could be executed several times
#                         using the option iteration
#       Cleanup         - Cleanup phase after test execution (remove files ..).
#
#
# Memory Checks:
#
#    When the -memory flag is set, the scripts checks the memory of the process
#    after each iteration. By default, it looks for a process Id specified
#    in command line with a -pid parameter, if there is none, it uses a pid
#    attribut of the object that you can set by any convenient way.
#
#    It is logical to specify multiple iterations when you want to check for memory
#    leaks. In addition of logging the memory level after each iteration,
#    this option triggers a test after all operation. A process is supposed
#    not to leak when the highwater mark for memory has been reach
#    before half of the iterations. It means that if you run the test
#    with ten iteration, the test fails if it has not reach the highwater
#    mark before the 5'th iteration.
#
#    This value is quite arbitray, we just want to check that the memory
#    usage reach a maximum within a certain number of iterations and then
#    stay stable or decrease.
#
# Performance Checks:
#
#    When this flag is set each iteration time is measured and at the end
#    a global report is printed with
#       - The number of iterations
#       - the average, mininmal and maximal time for iterations
#
# Requirements Management:
#
#    It is a "poor man" requirement management system. It is
#    convenient to store the list of tested requirements in the test
#    itself, so the test module have some methods to manage a
#    list of requirements. A test can check a requirement
#    statically if the requirement is checked each time that you
#    run the test. Or dynamically if the test checks the requirement
#    depending on the input data. In this case the requirement
#    is only checked with some scenarios.
#
#    Static requirements can be initialyzed by passing a 'requirements'
#    hash entry to the construtor. This requirement must contain a
#    reference to a identifier list.
#
#    Dynamic requirements can be added dynamically by calling
#    the addRequirements method. This method also have a reference
#    to a list parameter.
#
#    At the end of its execution or in documentation mode, the test
#    can print the list of requirements which have been checked.
#    By joining this information with a requirement description list
#    which associates requirments with their description, it must
#    be easy to generate traceability matrix (a list of requirments
#    with the list of tests which have checked them)
#
# ------------------------------------------------------------------------

########################################################################
package Test;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use Exporter;

use Time::HiRes qw(gettimeofday);
use MemoryMonitor;
use Script;
use ExecutionContext;
use Carp;
use XML::Writer;

use constant TRUE  => 1;
use constant FALSE => 0;

$VERSION = 1;

@ISA = qw(Script);

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
	my $Self = shift;

	# Call the parent initialization first
	$Self->Script::_init(@_);

	# Keywors default
	$Self->{keywords}        = [];
	$Self->{requirements}    = [];
	$Self->{success}         = 0;
	$Self->{failures}        = 0;
	$Self->{failuresReasons} = "";
	$Self->{synopsis}        = "";
	$Self->{'iteration'}     = 1;
	$Self->{'useTestMore'}   = 0;
	$Self->{'exitOnFailure'} = 0;

	# Call the parent initialization first
	$Self->Script::_init(@_);

	# Then initialize the test specific part
	unless ( $Self->{'testId'} ) {
		$Self->{'testId'} = ExecutionContext::basename();
	}

	$Self->debug("Test _init");
}

# ------------------------------------------------------------------------
# method: _found (private)
#
# Search for an element inside a list
#
# Parameters:
#   $pattern - pattern to look for
#   $listref - reference to the list
#   $useregexp - boolean, when true use a regular expression
# Return: true when found, false when not found
# ------------------------------------------------------------------------
sub _found {
	my ( $pattern, $listref, $useregexp ) = @_;

	my $result = 0;    # not found
	foreach my $elt ( @{$listref} ) {
		if ( ( $useregexp && ( $pattern =~ $elt ) ) || ( $pattern eq $elt ) ) {
			$result = 1;
			last;
		}
	}
	return $result;
}

# ------------------------------------------------------------------------
# method: passed
#
#   log that a check has been succesful
#
# Parameters:
#    $msg - string to log
# ------------------------------------------------------------------------
sub passed {
	my ( $Self, $msg ) = @_;

	$Self->{success}++;
	$Self->info( "PASSED " . $Self->{success} . " " . $msg, ".Checks" );
}

# ------------------------------------------------------------------------
# method: logCounter
#
#   log on counter logger, this logger is specialized into numeric or
#   statistic information like bandwidth, memory and CPU usage, etc.
#   It is recommended to use a syntax, like "COUNTER=VALUE"
#
# Parameters:
#    $msg - string to log
# ------------------------------------------------------------------------
sub logCounter {
	my ( $Self, $msg ) = @_;

	$Self->info( $msg, ".Counters" );
}

sub logScalarCounter {
	my ( $Self, $msg ) = @_;

	# $Self->info( $msg, ".Counters.Scalar" );
	$Self->info( $msg, ".Counters" );
}

sub logTableCounter {
	my ( $Self, $msg ) = @_;

	$Self->info( $msg, ".Counters.Table" );
}

# ------------------------------------------------------------------------
# method: logLowLevelIO
#
#   log to the low level IO logger. You should use this logger to trace
#   binary data.
#
# Parameters:
#    $msg - string to log
# ------------------------------------------------------------------------
sub logLowLevelIO {
	my ( $Self, $msg ) = @_;

	$Self->debug( $msg, ".IO" );
}

# ------------------------------------------------------------------------
# method: logHighLevelIO
#
#   log to the high level IO logger. You should use this logger to trace
#   symbolic, human readable data.
#
# Parameters:
#    $msg - string to log
# ------------------------------------------------------------------------
sub logHighLevelIO {
	my ( $Self, $msg ) = @_;

	$Self->info( $msg, ".IO" );
}

# ------------------------------------------------------------------------
# method: failed
#
#   log that a check has failed.
#
# Parameters:
#    $msg - string to log
# ------------------------------------------------------------------------
sub failed {
	my ( $Self, $msg ) = @_;

	$Self->{failures}++;
	my $total = $Self->{success} + $Self->{failures};
	$Self->error( "FAILED $total " . $msg, ".Checks" );
	$Self->{'failuresReasons'} .= $msg . "\n";

	if ( $Self->{'exitOnFailure'} ) {
		$Self->fatal("Test aborted on fatal error");
		$Self->CleanUp();
		exit();
	}
}

# ------------------------------------------------------------------------
# method: ok
#
#   Assertion check. The string to log is logged on the check logger at
#   passed of failed level depending on the result.
#
# Parameters:
#   $assertion - boolean assertion
#   $msg - string to log on the check logger.
# ------------------------------------------------------------------------
sub ok {
	my ( $Self, $assertion, $msg ) = @_;

	if ( $Self->{'useTestMore'} ) {
		Test::More::ok( $assertion, $msg );
	}
	else {
		if ($assertion) {
			$Self->passed($msg);
		}
		else {
			$Self->failed($msg);
		}
	}
}

# ------------------------------------------------------------------------
# method: is
#
#   Assertion check. This version checks that the two first parameters
#   are equal. The string to log is logged on the check logger at
#   passed of failed level depending on the result.
#
# Parameters:
#   $value - first parameter of the comparison
#   $expected - second parameter of the comparison
#   $msg - string to log on the check logger.
#
# TODO check that it compare all the possible types
# ------------------------------------------------------------------------
sub is {
	my ( $Self, $value, $expected, $msg ) = @_;

	if ( $Self->{'useTestMore'} ) {
		return Test::More::is( $value, $expected, $msg );
	}
	else {
		if ( $value eq $expected ) {
			$Self->passed($msg);
			return 1;
		}

		if ( $value == $expected ) {
			$Self->passed($msg);
			return 1;
		}

		$Self->failed( $msg . ", found " . $value );
		return 0;
	}
}

# ------------------------------------------------------------------------
# method: printContext
#
#   Print information about the script execution context
# ------------------------------------------------------------------------
sub printContext {
	my $Self = shift;

	# Call the parent version first
	foreach my $line ( split( /\n/, ExecutionContext::context() ) ) {
		$Self->doc($line);
	}

	$Self->doc( "Synopsis = " . $Self->{'synopsis'} );
	$Self->doc( "Keywords = " . join( ", ", @{ $Self->{keywords} } ) );
	$Self->doc( "Requirements = " . join( ", ", @{ $Self->requirements() } ) );
}

# ------------------------------------------------------------------------
# method: TestMuDEVICEeSkipped
#
# Tell if the test must be skipped or not. The method takes a lis of keywords
# as input parameter. Keywords are compared to the match and skip lists
# defined by configuration. If the match table is empty, this means that all tests match
#
# Parameters:
#     keywords - the list of keywords to check
#
# Todo: Next version should return the reason to skip or to match. For
#     example : "Skipped because it is a cleanup" or "Executed because it is a TRU64"
# ------------------------------------------------------------------------
sub TestMuDEVICEeSkipped {
	my $Self        = shift;
	my $keywordsref = shift;

	my @TestIdent = @{$keywordsref};

	my $MatchRef    = $Self->{'match'};
	my $SkipRef     = $Self->{'skip'};
	my $NbMatchElem = ($MatchRef) ? @$MatchRef : 0;
	my $NbSkipElem  = ($SkipRef) ? @$SkipRef : 0;
	my $TestSkipped = 0;

	my $keywords = "";
	foreach my $k (@TestIdent) {
		$keywords .= "$k ";
	}
	$Self->trace( "Test matching for  (" . $keywords . ")" );

	if ( $NbMatchElem != 0 ) {

	   # match table is not empty
	   # Test must be executed only if one test identification is in match array
		$TestSkipped = 1;
		foreach my $MatchElem (@$MatchRef) {
			foreach my $TestIdentElem (@TestIdent) {

				#print " ---- $TestIdentElem ---- $MatchElem\n";
				if ( $TestIdentElem eq $MatchElem ) {
					$TestSkipped = 0;
				}
			}
		}
	}

	if ( $TestSkipped == 0 && $NbSkipElem != 0 ) {
		foreach my $SkipElem (@$SkipRef) {
			foreach my $TestIdentElem (@TestIdent) {

				#print " ======= $TestIdentElem - $SkipElem \n";
				if ( $TestIdentElem eq $SkipElem ) {
					$TestSkipped = 1;
				}
			}
		}
	}
	return $TestSkipped;
}

# ------------------------------------------------------------------------
# method: SetUp
#
# Test preparation, empty when nothing to do. Can be skipped if the
# test context can be setup for several test executions.
# ------------------------------------------------------------------------
sub SetUp {
	my $Self = shift;

	$Self->trace("SetUp");
	$Self->{success}  = 0;
	$Self->{failures} = 0;
}

# ------------------------------------------------------------------------
# method: TestMain
#
# Test main routine. It is this method which is executed several times
# when the *-iteration* parameter is more than 1.
# ------------------------------------------------------------------------
sub TestMain {
	my $Self = shift;

	$Self->trace("TestMain procedure executed");
	ok( 1, "Subtest 1" );
	ok( 1, "Subtest 2" );
}

# ------------------------------------------------------------------------
# method: CleanUp
#
# Test cleanup, for example delete all the test generated files.
# ------------------------------------------------------------------------
sub CleanUp {
	my $Self = shift;

	$Self->trace("CleanUp");

	if ( $Self->{failures} == 0 ) {
		$Self->warn(
"PASSED global $Self->{testId}, success=$Self->{success}, failures=0",
			".Checks"
		);
	}
	else {
		$Self->error(
"FAILED global $Self->{testId}, success=$Self->{success}, failures=$Self->{'failures'}",
			".Checks"
		);
		$Self->error(
			"FAILED because $Self->{testId} $Self->{'failuresReasons'}",
			".Checks" );
	}
	if ( $Self->{'junit'} ) {
		$Self->_junit();
	}
}

# ------------------------------------------------------------------------
# method: run
#
# Launch the test execution
# ------------------------------------------------------------------------
sub run {
	my $Self = shift;

	my $start_time;
	my $stop_time;
	my $iter_start_time;
	my $iter_time;
	my $total_time;
	my $max = -1;
	my $min = 1000000000;

	# identification and log
	my $TestName = $Self->{testId};
	$Self->printContext();

	if ( $Self->TestMuDEVICEeSkipped( $Self->{keywords} ) ) {
		$Self->trace("Test $TestName is skipped");
	}
	else {
		$Self->trace("Test $TestName started");
		$start_time = gettimeofday;

		# Setup
		$Self->SetUp();

		# memory check
		if ( $Self->{'memory'} ) {
			my $pid = $Self->{'pid'};

			unless ( exists( $Self->{'memo'} ) ) {
				$Self->{'memo'} = new MemoryMonitor(
					'pid'    => $pid,
					'use_ps' => 0
				);
			}
		}

		# main loop
		for ( my $iter = 1 ; $iter <= $Self->{'iteration'} ; $iter++ ) {

			# make a memory measure
			if ( defined( $Self->{'memo'} ) ) {
				my $mem  = $Self->{'memo'}->measure();
				my $unit = $Self->{'memo'}->unit();
				my $pid  = $Self->{'memo'}->pid();

				$Self->logTableCounter( 'iteration = ' 
					  . $iter
					  . ', memory = '
					  . $mem . " "
					  . $unit
					  . ', pid = '
					  . $pid );
			}

			$iter_start_time = gettimeofday;

			$Self->TestMain(@ARGV);

			$stop_time = gettimeofday;
			$iter_time = $stop_time - $iter_start_time;
			$max       = $iter_time if ( $iter_time > $max );
			$min       = $iter_time if ( $iter_time < $min );

			$Self->logScalarCounter(
				"IterationTime = $iter_time, Iteration = $iter");
		}

		# end dof main loop

		$total_time = gettimeofday - $start_time;
		$Self->{'total_time'} = $total_time;

		# Save performance data
		if ( $Self->{'performance'} ) {

			$Self->logScalarCounter( "TotalTime = " . $total_time );
			if ( $Self->{'iteration'} > 1 ) {
				$Self->{'average_time'} = $total_time / $Self->{'iteration'};

				$Self->logCounter("Iterations = $Self->{'iteration'}\n");
				$Self->logScalarCounter(
					"AverageIterationTime = $Self->{'average_time'}\n");
				$Self->logScalarCounter("MaxIterationTime = $max\n");
				$Self->logScalarCounter("MinIterationTime = $min\n");
			}
		}

		# Check for memory leak
		if ( defined( $Self->{'memo'} ) ) {
			my $memo = $Self->{'memo'};
			die "not enough memory measure to estimate memory leaks"
			  if ( $memo->measureCount < $memo->size() );

			my $delta_value = $memo->delta_value();
			my $nb          = $memo->measureCount();
			if ($nb) {
				my $leak_rate = $delta_value / $nb;
				$Self->ok(
					( $leak_rate < $memo->{'acceptable_leak_per_measure'} ),
					"average memory per measure = "
					  . $leak_rate
					  . " >= acceptable rate = "
					  . $memo->{'acceptable_leak_per_measure'}
				);
			}

			my $delta_time = $memo->delta_time();
			if ($delta_time) {
				my $leak_rate = $delta_value / $delta_time;
				$Self->ok(
					( $leak_rate < $memo->{'acceptable_leak_per_second'} ),
					"average memory per second = "
					  . $leak_rate
					  . " >= acceptable rate = "
					  . $memo->{'acceptable_leak_per_second'}
				);

			}

			my $msg =
			    'Highwatermark = '
			  . $Self->{'memo'}->memoryPeak() . ' at '
			  . $Self->{'memo'}->peakPercentage() . '%';

			$Self->logTableCounter($msg);
		}

		# Cleanup
		$Self->CleanUp();

		return -1 * $Self->{'failures'};
	}
}

# ------------------------------------------------------------------------
# method: requirements
#
# If a list of requirements is supplied, they are added to the current
# list. Requirements are only added when they do not already exist.
#
# Parameters:
#    $listref - reference to a new list of requirements
#
# Returns: a pointeru to a list of requirements identifiers
# ------------------------------------------------------------------------
sub requirements {
	my ( $Self, $listref ) = @_;

	if ( defined($listref) ) {
		foreach my $req ( @{$listref} ) {
			unless ( _found( $req, $Self->{'requirements'} ) ) {
				push( @{ $Self->{'requirements'} }, $req );
			}
		}
	}
	return $Self->{'requirements'};
}

# ------------------------------------------------------------------------
# method: addRequirement
#
# Add one requirment to the list
#
# Parameters:
#    $req - new requirement
# ------------------------------------------------------------------------
sub addRequirement {
	my ( $Self, $req ) = @_;

	unless ( _found( $req, $Self->{'requirements'} ) ) {
		push( @{ $Self->{'requirements'} }, $req );
	}
}

# Perl trim function to remove whitespace from the start and end of the string
sub trim($)
{
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

# ------------------------------------------------------------------------
# method: _junit (private)
#
# Generates the rest of the Junit xml file result
# ------------------------------------------------------------------------
sub _junit {
	my ($Self) = @_;

	my $junit = $Self->{'junit'};
	# print "generating Junit footer: $junit\n";

	my $fd;
	open( $fd, "> $junit" ) or die("cannot open file $junit : $!");

	print $fd "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
	my $xml = XML::Writer->new( OUTPUT => $fd, NEWLINES => 0 );
	my $hostname = `hostname`;
	chomp($hostname);
	my $date = `date`;
	chomp($date);
	my $failures = $Self->{'failures'};
	my $time     = $Self->{'total_time'};

	$xml->startTag(
		"testsuite",
		"errors"    => "0",
		"failures"  => $failures,
		"hostname"  => $hostname,
		"name"      => $Self->{'testId'},
		"tests"     => 1,
		"time"      => $time,
		"timestamp" => $date
	);
	print $fd "\n";

	# Generates the properties
	foreach my $line ( split( /\n/, ExecutionContext::context() ) ) {
		if ( $line =~ /(.*)\s*=\s*(.*)/ ) {
			my $name = trim($1);

			$xml->startTag(
				"property",
				name  => $name,
				value => $2
			);
			$xml->endTag("property");
			print $fd "\n";
		}
	}

	# Property synopsis
	$xml->startTag(
		"property",
		name  => "Synopsis",
		value => $Self->{'synopsis'}
	);
	$xml->endTag("property");
	print $fd "\n";

	# Execution environement variables
	# TODO

	# subtest list
	$xml->startTag(
		"testcase",
		classname => "Simulation",
		name      => $Self->{'testId'},
		time      => $time
	);
	if ( $Self->{failures} != 0 ) {
		print $fd "\n";
		$xml->startTag(
			"failure",
			message      => $Self->{'failuresReasons'}
		);
		$xml->endTag("failure");
		print $fd "\n";
	}
	$xml->endTag("testcase");
	print $fd "\n";

	$xml->startTag("system-out");
	print $fd "<![CDATA[";
	my $logfilename = main::logFilename();
	open(LOG, $logfilename) || die("Could not open file $logfilename!");
    my $data=<LOG>;
    close(LOG); 
	print $fd $data;
	print $fd "]]>";
	$xml->endTag("system-out");

	#
	print $fd "\n";
	$xml->startTag("system-err");
	print $fd "<![CDATA[";
	print $fd "]]>";
	$xml->endTag("system-err");

	print $fd "\n";
	$xml->endTag("testsuite");

	$xml->end();
	close($fd);
}

# ------------------------------------------------------------------------
1;
