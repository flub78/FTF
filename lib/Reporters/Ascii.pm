# ----------------------------------------------------------------------------
#
# Title: Class Reporters::Reporter::ASCII
#
# Name:
#
#    package Reporters::Reporter::ASCII
#
# Abstract:
#
#    Test reporter. This is a test report generator.
#    This one generates an ASCII report compatible with NaturalDocs.
#    Not necessary very good looking, but it is tha fastest that
#    I have found to generate an HTML report with some navigation
#    links to individual tests results.
#
#    A more professional implementation would rather generate an
#    XML format that would be displayed with style sheets.
#
# Numerical values treatment:
#
# Several types of counters
#
#   - Unique test values
#   - tables
# ----------------------------------------------------------------------------
package Reporters::Ascii;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Exporter;
use Log::Log4perl;
use Data::Dumper;

$VERSION = 1;

@ISA = qw(Exporter);

# ------------------------------------------------------------------------
# method: new
#
# Returns a new initialised object for the class.
# ------------------------------------------------------------------------
sub new {
    my $Class = shift;
    my $Self  = {};

    bless( $Self, $Class );

    $Self->{Logger} = Log::Log4perl::get_logger($Class);
    $Self->{Logger}->debug("Creating instance of $Class");
    $Self->_init(@_);

    return $Self;
}

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    my %attr = @_;

    # Attribute initialization

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }
}

# ########################################################################

# ------------------------------------------------------------------------
# routine: section
#
# Generate a section header.
#
# Parameters:
#    $title - section name
# ------------------------------------------------------------------------
sub section {
    my ( $title, $fd ) = @_;

    print $fd "\n";
    my $str = "Section: " . $title;
    print $fd $str, "\n";
    print $fd "#" x length($str), "\n" x 2;
}

# ------------------------------------------------------------------------
# routine: title
#
# Generate a title header.
#
# Parameters:
#    $title - section name
# ------------------------------------------------------------------------
sub title {
    my ( $title, $fd ) = @_;

    print $fd "\n";
    my $str = "$title:";
    print $fd $str, "\n";
}

# ------------------------------------------------------------------------
# routine: gmt
# ------------------------------------------------------------------------
sub gmt {
    my ($epoch) = @_;

    my $res = "";
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      gmtime($epoch);
    $mon++;
    $year += 1900;

    $res .= "$year/$mon/$mday $hour:$min:$sec ";
    return $res;
}

# ------------------------------------------------------------------------
# routine: generate_global
#
#  generate the documentation
# ------------------------------------------------------------------------
sub generate_global {
    my ( $Self, $fd ) = @_;

    # Generate the report
    my $results = $Self->{'results'};
    $Self->{'Logger'}->trace("Generate ASCII test report");

    section( "Tests Execution Report", $fd );

    print $fd "\n";
    print $fd "Date                - " . `date`;
    print $fd "Generated on        - " . `hostname`;
    print $fd "Operating system    - " . `uname -a`;
    print $fd "Operator            - " . `whoami`;
    print $fd "Generator arguments - " . join( " ", @{ $Self->{argv} } ) . "\n";

    section( "Test Report Summary", $fd );

    # Header from the test cases list
    if ( defined( $Self->{'test_cases_list'} ) ) {
        print $fd
"The following description of the test suite comes from the test cases list header.\n\n";
        my $tcl = $Self->{'test_cases_list'};

        print $fd join( "\n\n", split( /\n/, $tcl->header() ) ), "\n" x 2;
    }

    # Global results
    print $fd "Global results:\n\n";

    print $fd "Number of tests - " . $results->{'totalCount'} . "\n";
    print $fd "Tests not found - "
      . $results->{'result'}->{'NOT_FOUND'} . "\n";
    print $fd "Tests aborted   - " . $results->{'result'}->{'ABORTED'} . "\n";
    print $fd "Tests FAILED    - " . $results->{'result'}->{'FAILED'} . "\n";
    print $fd "Tests PASSED    - " . $results->{'result'}->{'PASSED'} . "\n";

    # Global Tests Results
    section( "Global Tests Results", $fd );

    print $fd "Execution result for each test.\n\n";

    my $max = 20;
    foreach my $tstName ( @{ $results->{'tests'} } ) {
        if (length($tstName) > $max) {
            $max = length($tstName);
        }
    }
    $max++;
    my $title_frmt = "| %-" . $max . "s %-10s %-9s %-9s %-30s\n";
    printf $fd ( $title_frmt, "", "",, "Passed", "Failed" );

    printf $fd ( $title_frmt, "TestId", "Result", "sub-tests", "sub-tests",
        "Synopsis" );

    print $fd "\n";
    foreach my $tstName ( @{ $results->{'tests'} } ) {
        my $tst = $results->{'test'}->{$tstName};
        my $note = ( $tst->{'expected'} ) ? "" : "*";

        my $result = $tst->globalStatus() . $note;
        my $passed = $tst->passedSubTests();
        my $failed = $tst->failedSubTests();
        my $syn    = $tst->synopsis();
        my $frmt   = "| %-" . $max ."s %-10s %9i %9i %-30s\n";
        printf $fd ( $frmt, $tstName, $result, $passed, $failed, $syn );
    }

    printf $fd "\nTests marked with a \"*\" were not selected.\n";
}

# ------------------------------------------------------------------------
# routine: generate_traceability
#
#  generate the traceability matrices
# ------------------------------------------------------------------------
sub generate_traceability {
    my ( $Self, $fd ) = @_;

    $Self->{'Logger'}->trace("Generate ASCII traceability matrices");
    
    my $results = $Self->{'results'};

    section( "Requirements Treacability", $fd );

    print $fd "Tests per requirements and requirements per test.\n\n";

    title( "Tests per requirement", $fd );

    # Tests per requirement
    my @list = sort( @{ $results->{'req_list'} } );
    foreach my $r (@list) {
        my $line = "| ";
        $line .= sprintf( "%-20s", $r );
        my $nb      = scalar( @{ $results->{'requirement'}->{$r} } );
        my $passed  = $results->{'passed'}->{$r};
        my $percent = ( $nb == 0 ) ? 0 : int( ( $passed * 100 ) / $nb );
        $line .= sprintf( "%4i\% ", $percent );
        $line .= join( ", ", @{ $results->{'requirement'}->{$r} } );
        print $fd "$line\n";
    }

    # Requirements per test
    title( "Requirements per test", $fd );
    foreach my $tstName ( @{ $results->{'tests'} } ) {
        my $tst = $results->{'test'}->{$tstName};
        my $line =
          sprintf( "| %-20s %s\n", $tstName, $tst->variable("Requirements") );
        print $fd $line;
    }
}

# ------------------------------------------------------------------------
# routine: generate_tests
#
#  generate the documentation for each test
# ------------------------------------------------------------------------
sub generate_tests {
    my $Self = shift;

    my $results  = $Self->{'results'};
    my $filename = $Self->{'filename'};
    my $outDir   = $Self->{'outputDirectory'};
    my $fd;

    foreach my $tstName ( @{ $results->{'tests'} } ) {

        $Self->{'Logger'}->trace("Generate ASCII " . $tstName . " test report");
        # section("Individual Tests Results", $fd);
        # open a file for the test report
        if ($filename) {
            $filename = $outDir . $tstName . ".txt";
            open( $fd, "> $filename" )
              or die("cannot open file $filename : $!");
        }
        else {
            $fd = *STDOUT;
        }

        # test title
        section( $tstName, $fd );

        # test results extracted by the parser from assertion checks
        my $tst = $results->{'test'}->{$tstName};
        print $fd $tst->synopsis(), "\n\n";
        print $fd "\tGlobal result        - ", $tst->globalStatus(),   "\n";
        print $fd "\tPASSED sub-tests     - ", $tst->passedSubTests(), "\n";
        print $fd "\tFAILED sub-tests     - ", $tst->failedSubTests(), "\n";

        my $logname = $tst->filename();
        if ($filename) {
            $logname = "<file:../../../../" . $logname . ">";
        }
        print $fd "\tLog file             - ", $logname,       "\n";
        
        print $fd "\tExecution start time - ", gmt( $tst->startTime() ), "\n";
        print $fd "\tExecution end time   - ", gmt( $tst->endTime() ),   "\n";

        print $fd "\tCommand line Arguments - ",
          $tst->variable("Command line Arguments"), "\n";
        print $fd "\tRequirements - ", $tst->variable("Requirements"), "\n";

        # Test documentation, declared by the test itself
        my $doc = $tst->doc();
        if ($doc) {
            title( "Documentation", $fd );
            print $fd "\t", join( "\n\t", split( /\n/, $doc ) ), "\n";
        }

        # Extracted from the counter values
        $doc = $tst->counters();
        if ($doc) {
            title( "Counters", $fd );
            print $fd "\n";

            # single line counters
            foreach my $cnt ( $tst->counter_list() ) {
                print $fd "\t$cnt - " . $tst->counter_value($cnt) . "\n";
            }
            print $fd "\n";

            # multiple lines tables
            foreach my $table ( $tst->table_list() ) {

                title ("Table $table", $fd);

                print $fd "\n | ";
                foreach my $col ( $tst->table_columns($table) ) {
                    printf $fd ("%-20s | ", $col);
                }
                print $fd "\n";
                
                for ( my $i = 0 ; $i < $tst->table_size($table) ; $i++ )
                {   
                    print $fd " | ";
                    foreach my $col ( $tst->table_columns($table) ) {
                        printf $fd ("%20s | ",
                            $tst->table_value( $table, $col, $i ));
                    }
                    print $fd "\n";
                }

            }

        }

        close($fd);
    }
}

# ------------------------------------------------------------------------
# routine: generate
#
#  generate the documentation
# ------------------------------------------------------------------------
sub generate {
    my $Self = shift;

    my $filename = $Self->{'filename'};

    my $fd;
    if ($filename) {
        my $filename = $filename;
        open( $fd, "> $filename" ) or die("cannot open file $filename : $!");
    }
    else {
        $fd = *STDOUT;
    }

    $Self->generate_global($fd);
    $Self->generate_traceability($fd);
    $Self->generate_tests();

    close($fd);
    print "test report $filename generated\n";
}

1;
