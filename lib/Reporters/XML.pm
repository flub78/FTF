# ----------------------------------------------------------------------------
#
# Title: Class Reporters::XML
#
# Name:
#
#    package Reporters::XML
#
# Abstract:
#
#    Test reporter. This is a test report generator.
#    This one generates an XML report.
#
# Numerical values treatment:
#
# Several types of counters
#
#   - Unique test values
#   - tables
# ----------------------------------------------------------------------------
package Reporters::XML;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Exporter;
use Log::Log4perl;
use Data::Dumper;
use XML::Writer;
use IO::File;

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

    my $output = new IO::File( ">" . $Self->{'filename'} );
    $Self->{'xml'} = XML::Writer->new();
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
    my ( $Self, $title, $fd ) = @_;

    my $xml = $Self->{'xml'};

    $xml->startTag(
        "Section",    
        "name" => $title
    );
    $xml->endTag("Section");    
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
    my ( $Self, $title, $fd ) = @_;

    $Self->{'xml'}->startTag(
        "Title",    
        "name" => $title
    );
    $Self->{'xml'}->endTag("Title");
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
    my $xml = $Self->{'xml'};

    $Self->section( "Tests Execution Report", $fd );

    my ( $date, $hostname, $uname, $operator ) =
      ( `date`, `hostname`, `uname -a`, `whoami` );
    chomp($date);
    chomp($hostname);
    chomp($uname);
    chomp($operator);
    my $args = join( " ", @{ $Self->{argv} } );
    
    $Self->{'xml'}->startTag(
        "Global_Report",    
        'Date' => $date,
        'Hostname' => $hostname,
        'Operating_System' => $uname,
        'Operator' => $operator,
        'Generator_Arguments' => $args
    );
    $Self->section( "Test Report Summary", $fd );

    if ( defined( $Self->{'test_cases_list'} ) ) {
        print $fd
"The following description of the test suite comes from the test cases list header.\n\n";
        my $tcl = $Self->{'test_cases_list'};

        print $fd join( "\n\n", split( /\n/, $tcl->header() ) ), "\n" x 2;
    }

    $Self->{'xml'}->startTag(
        "Global_Results",
        'Number_Of_Tests' => $results->{'totalCount'},
        'Tests_Not_Found' => $results->{'result'}->{'NOT_FOUND'},
        'Tests_Aborted'   => $results->{'result'}->{'ABORTED'},
        'Tests_FAILED'    => $results->{'result'}->{'FAILED'},
        'Tests_PASSED'    => $results->{'result'}->{'PASSED'});
    $Self->{'xml'}->endTag("Global_Results");

    $Self->section( "Global Tests Results", $fd );

    print $fd "Execution result for each test.\n";

    foreach my $tstName ( @{ $results->{'tests'} } ) {
        my $tst  = $results->{'test'}->{$tstName};
       
        $Self->{'xml'}->startTag(
            "Test_Summary",
            'Status'     => $tst->globalStatus(),
            'Expected'   => $tst->{'expected'},
            'Sub_PASSED' => $tst->passedSubTests(),
            'Sub_FAILED' => $tst->failedSubTests(),
            'Synopsis'   => $tst->synopsis()
        );
        $Self->{'xml'}->endTag("Test_Summary");
    }

    printf $fd "\nTests marked with a \"*\" were not selected.\n";
    $Self->{'xml'}->endTag("Global_Report");
}

# ------------------------------------------------------------------------
# routine: generate_traceability
#
#  generate the traceability matrices
# ------------------------------------------------------------------------
sub generate_traceability {
    my ( $Self, $fd ) = @_;

    my $results = $Self->{'results'};

    $Self->section( "Requirements Treacability", $fd );

    # Tests per requirement
    my @list = sort( @{ $results->{'req_list'} } );
    foreach my $r (@list) {
        
        my $nb      = scalar( @{ $results->{'requirement'}->{$r} } );
        my $passed  = $results->{'passed'}->{$r};
        my $percent = ( $nb == 0 ) ? 0 : int( ( $passed * 100 ) / $nb );
        
        $Self->{'xml'}->startTag(
            "Tests_Per_Requirement",
            'Requirement' => $r,
            'Percentage'  => $percent,
            'Tests'       => join( ", ", @{ $results->{'requirement'}->{$r} } )
        );
        $Self->{'xml'}->endTag("Tests_Per_Requirement");
    }

    # Requirements per test
    $Self->title( "Requirements per test", $fd );
    foreach my $tstName ( @{ $results->{'tests'} } ) {
        my $tst  = $results->{'test'}->{$tstName};

        $Self->{'xml'}->startTag(
            "Requirements_Per_Test",
            'Test'         => $tstName,
            'Requirements' => $tst->variable("Requirements")
        );
        $Self->{'xml'}->endTag("Requirements_Per_Test");
    }
}

# ------------------------------------------------------------------------
# routine: generate_tests
#
#  generate the documentation for each test
# ------------------------------------------------------------------------
sub generate_tests {
    my ( $Self, $fd ) = @_;

    my $results  = $Self->{'results'};
    my $filename = $Self->{'filename'};
    my $outDir   = $Self->{'outputDirectory'};

    foreach my $tstName ( @{ $results->{'tests'} } ) {

        # test title
        $Self->section( $tstName, $fd );

        # test results extracted by the parser from assertion checks
        my $tst = $results->{'test'}->{$tstName};
                 
        $Self->{'xml'}->startTag(
            "Test_Result",
            'Status'     => $tst->globalStatus(),
            'Expected'   => $tst->{'expected'},
            'Sub_PASSED' => $tst->passedSubTests(),
            'Sub_FAILED' => $tst->failedSubTests(),
            'Synopsis'   => $tst->synopsis(),
            'Log_File'   => $tst->filename(),
            'Execution_Start' => gmt( $tst->startTime() ),
            'Execution_End'   => gmt( $tst->endTime() ),
            'Command_Line_Arguments' => $tst->variable("Command line Arguments"),
            'Requirements'           => $tst->variable("Requirements")
        );
        

        # Test documentation, declared by the test itself
        my $doc = $tst->doc();
        if ($doc) {
            $Self->title( "Documentation", $fd );
            print $fd "\t", join( "\n\t", split( /\n/, $doc ) ), "\n";
        }

        # Extracted from the counter values
        $doc = $tst->counters();
        if ($doc) {
            $Self->title( "Counters", $fd );
            print $fd "\n";

            # single line counters
            foreach my $cnt ( $tst->counter_list() ) {
                $Self->{'xml'}->startTag(
                    "Counter",
                    'Name'     => $cnt,
                    'Value'    => $tst->counter_value($cnt)
                );
                $Self->{'xml'}->endTag("Counter");
            }

            # multiple lines tables
            foreach my $table ( $tst->table_list() ) {

                $Self->{'xml'}->startTag(
                    "Table",
                    "Name"    => $table,
                );

                for ( my $i = 0 ; $i < $tst->table_size($table) ; $i++ ) {
                    $Self->{'xml'}->startTag(
                        "Line",
                        "Index"    => $i,
                    );
                    
                    foreach my $col ( $tst->table_columns($table) ) {
                        $Self->{'xml'}->startTag(
                            "Cell",
                            "Column"    => $col,
                            "Value"     => $tst->table_value( $table, $col, $i )
                        );
                        $Self->{'xml'}->endTag("Cell");
                    }
                    $Self->{'xml'}->endTag("Line");
                }
                $Self->{'xml'}->endTag("Table");
            }
        }
        $Self->{'xml'}->endTag("Test_Result");
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

    my $xml = XML::Writer->new( OUTPUT => $fd, NEWLINES => 1 );
    $Self->{'xml'} = $xml;


    $xml->startTag(
        "Automated_Tests_Report",    
        "class" => "simple"
    );
    $Self->generate_global($fd);
    $Self->generate_traceability($fd);
    $Self->generate_tests($fd);

    $xml->endTag("Automated_Tests_Report");
    $xml->end();
    close($fd);
    print "test report $filename generated\n";
}

1;
