# ------------------------------------------------------------------------
# Title:  Test cases list anr reports generator
#
# File - scripts/tcl.pl
# Version - 1.0
#
# Abstract:
#
#    This script has several modes.
#    - Generation of a script from a comma separated value spreadsheet.
#    - report generation
#    - Import of the result into the csv spreadsheet.
#
# Script generation mode:
#
#    - Each column in the test suite is converted into a
#    command line parameter.
#
#    - Multiple values inside a column are converted into multiple
#    command line parameters.
#
#    - output of this script is compatible with the perlTest Tools
#    scripts command line parameters.
#
# Report generation mode:
#
#    The script parse the result directory to analyze the logs.
#    Then it generates a report. Several report format are
#    supported.
#
#    In this mode the spreadsheet is optional. When you supply
#    one on the command line, it is used to include the header
#    and to compare the results with the expected ones.
#
# Result import mode:
#
#    In this mode the result of the tests execution is imported
#    back in the spreadsheet into a specified column.
#
#
# (start code)
# Example of generation of a test suite script:
#
# perl tcl.pl -title 4 \
#    -col testId \
#    -synopsis "Synopsis" \
#    -test "engine" \
#    -argument iteration \
#    -argument "outputDirectory" \
#    -flag fail \
#    -csv requirement \
#    -selector selected \
#    test_suite.csv
#
# Example of result analysis:
#
# perl tcl.pl \
#    -report report.txt \
#    -format ASCII \
#    -title 4 \
#    -result run1 \
#    -testId testId \
#    -directory run1 \
#    -selector selected \
#    test_suite.csv
#
# (end)
# ------------------------------------------------------------------------
package TestCasesList;

use strict;
use lib "$ENV{'FTF'}/lib";
use Script;

use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Data::Dumper;
use File::Basename;

use ExecutionContext;
use ScriptConfiguration;
use Reporters::List;
use Reporters::DirectoryResultParser;
use Reporters::Ascii;
# use Reporters::OO;
use Reporters::XML;

$VERSION = 1;
@ISA     = qw(Script);

my $name = ExecutionContext::basename();

my @argv        = @ARGV;
my $help_header = "
usage: perl $name.pl [options]";

my $help_footer = "
Example:

       perl $name.pl -help
       
Example of generation of a test suite script:

perl tcl.pl -title 4 \
   -col testId \
   -synopsis \"Synopsis\" \
   -test \"engine\" \
   -argument iteration \
   -argument \"outputDirectory\" \
   -flag fail \
   -csv requirement \
   -selector selected \
   test_suite.csv

Example of result analysis:

perl tcl.pl \\
   -report report.txt \\
   -format ASCII \
   -title 4 \
   -result run1 \
   -testId testId \
   -directory run1 \
   -selector selected \
    test_suite.csv
    
perl tcl.pl \\
   -report report.txt \\
   -format ASCII \\
   -result . \\
   -testId testId \\
   -directory . 
";

my $config = new ScriptConfiguration(
	'header'     => $help_header,
	'footer'     => $help_footer,
	'scheme'     => SCRIPT,
	'parameters' => {
		script => {
			type        => "string",
			description => "Name of the the script to generate from the csv",
			default     => ""
		},

		# Test cases list usage
		title => {
			type        => "string",
			description => "line containing the column labels",
			default     => 1
		},
		lastLine => {
			type        => "string",
			description => "last line to proceed",
			default     => "900000"
		},
		testId => {
			type => "string",
			description =>
"id of the column containing the test identification (mandatory for result analyze)",
			default => "testId"
		},
		synopsis => {
			type        => "string",
			description => "id of the column containing the test synopsys",
			default     => "Synopsis"
		},
		selector => {
			type        => "string",
			description => "id of the column containing the test selector",
			default     => undef
		},
		flag => {
			type        => "array",
			description => "generate a flag parameter (ex: -binary)",
			default     => []
		},
		parameter => {
			type        => "array",
			description => "generate single parameter (ex: -file filename.txt)",
			default     => []
		},
		argument => {
			type        => "array",
			description => "include argument in command line",
			default     => []
		},
		csv => {
			type => "array",
			description =>
			  "generate multiple parameter. They are comma separated",
			default => []
		},

		# Result import
		resultColumn => {
			type        => "string",
			description => "column to fill with the result",
			default     => ""
		},
		directory => {
			type        => "string",
			description => "Directory to parse to import the result",
			default     => ""
		},

		# Report generation
		filter => {
			type => "string",
			description =>
"files filter, only take into account result files matching this regular expression",
			default => ""
		},
		report => {
			type        => "string",
			description => "name of the generated report",
			default     => ""
		},
		format => {
			type        => "string",
			description => "Test report format (ASCII | XML | OO)",
			default     => "ASCII"
		},
		template => {
			type        => "string",
			description => "Template for test report generation",
			default     => ""
		},
		group => {
			type        => "string",
			description => "Category column name for report organization",
			default     => ""
		}
	},
);

# ########################################################################

# ------------------------------------------------------------------------
# method: importResult
#
#  Scrip main method.
#
#  Parameters:
#     tcl - test case list to update
#     resultCol - name of the column to put the result
# ------------------------------------------------------------------------
sub importResult {
	my ( $Self, $tcl, $resultCol ) = @_;

	$Self->trace( "importing results for " . $tcl->filename() );

	my $directory = $Self->{'config'}->value('directory');
	die "-directory mandatory to import results into test cases list."
	  unless ( defined($directory) );

	my $filter = $Self->{'config'}->value('filter');

	my $resultIdx = $tcl->column($resultCol);
	die "$resultCol not found in speadsheet"
	  unless ( $resultIdx >= 0 );

	# Parse the result files
	my $results = new TCL::DirectoryResultParser(
		directory => $directory,
		filter    => $filter
	);

	# die Dumper($results);
	my @selected = $tcl->selectedTests();
	foreach my $tst (@selected) {
		my $res = 'NOT_FOUND';
		if ( $results->testResult($tst) ) {
			$res = $results->testResult($tst)->globalStatus();
		}
		$tcl->cell_by_name( $tst, $resultCol, $res );

		# print "$tst $res : ", $tcl->cell_by_name($tst, $resultCol), "\n";
	}
	$tcl->save();
}

# ------------------------------------------------------------------------
# method: run
#
#  Scrip main method.
# ------------------------------------------------------------------------
sub run {
	my $Self = shift;

	my $titleLine    = $Self->{'config'}->value('title');
	my $last         = $Self->{'config'}->value('lastLine');
	my $synopsis     = $Self->{'config'}->value('synopsis');
	# my $command      = $Self->{'config'}->value('command');
	my $testId       = $Self->{'config'}->value('testId');
	my $selector     = $Self->{'config'}->value('selector');
	my $flag         = $Self->{'config'}->value('flag');
	my $parameter    = $Self->{'config'}->value('parameter');
	my $argument     = $Self->{'config'}->value('argument');
	my $csv          = $Self->{'config'}->value('csv');
	my $directory    = $Self->{'config'}->value('directory');
	my $script       = $Self->{'config'}->value('script');
	my $filter       = $Self->{'config'}->value('filter');
	my $report       = $Self->{'config'}->value('report');
	my $resultColumn = $Self->{'config'}->value('resultColumn');
	my $format       = $Self->{'config'}->value('format');
	my $template     = $Self->{'config'}->value('template');
	my $group        = $Self->{'config'}->value('group');

	my $csvfile = $ARGV[0];

	# print "CSV file = $csvfile\n";

	my $tcl;
	if ( -f $csvfile ) {
		$tcl = new TCL::List(
			filename  => $csvfile,
			titleLine => $titleLine,
			last      => $last,
			testId    => $testId,
			lineName  => $testId,
			selector  => $selector,
			synopsis  => $synopsis,
			argument  => $argument,
			parameter => $parameter,
			flag      => $flag,
			csv       => $csv,
			group     => $group
		);

		if ($resultColumn) {

			# import the result
			$Self->importResult( $tcl, $resultColumn );
			print "results from $directory imported into $csvfile\n";
		}

		if ($script) {

			# generate the test run script
			$tcl->script( $script, \@argv );
			print "script $script generated\n";
		}
	}
	else {
		if ( defined($csvfile) ) {
			die "Cannot find $csvfile file.";
		}
	}

	if ($report) {

		# Parse the result files
		my $results = new Reporters::DirectoryResultParser(
			directory       => $directory,
			filter          => $filter,
			test_cases_list => $tcl
		);

		if ( $report =~ /^\// ) {

			# absolute path
		}
		else {

			# relative path
			my $pwd = `pwd`;
			chomp($pwd);
			$report = $pwd . '/' . $report;
		}
		my ( $base, $dir, $ext ) = fileparse($report);

		my $reporter;

		if ( $format eq 'ASCII' ) {
			$reporter = new Reporters::Ascii(
				filename        => $report,
				outputDirectory => $dir,
				results         => $results,
				argv            => \@argv,
				test_cases_list => $tcl
			);
		}
		elsif ( $format eq 'XML' ) {
			$reporter = new Reporters::XML(
				filename        => $report,
				outputDirectory => $dir,
				results         => $results,
				argv            => \@argv,
				test_cases_list => $tcl
			);
		}
		elsif ( $format eq 'OO' ) {
			die "template is mandatory for Open Office generation"
			  unless ($template);

			die "file $template not found"
			  unless ( -f $template );

			$reporter = new Reporters::OO(
				filename        => $report,
				outputDirectory => $dir,
				results         => $results,
				argv            => \@argv,
				test_cases_list => $tcl,
				template        => $template,
				test_cases_list => $tcl
			);

		}
		else {
			die "unknown report format $format";
		}

		$reporter->generate();
	}
}

my $script = new TestCasesList(config => $config);
$script->run();
