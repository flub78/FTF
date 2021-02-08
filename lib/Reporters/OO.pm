# ----------------------------------------------------------------------------
#
# Title: Class Reporters::Reporter::OO
#
# Name:
#
#    package Reporters::Reporter::OO
#
# Abstract:
#
#    Test reporter. Open Office format.
#
# TODO: Support for counters graphical display
# ----------------------------------------------------------------------------
package Reporters::OO;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Exporter;
use Log::Log4perl;
use Data::Dumper;
use Doc::DocGen;

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
    my ( $title, $doc ) = @_;

    $doc->appendHeading( 1, $title );
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
    my ( $title, $doc ) = @_;

    $doc->appendHeading( 2, $title );
}

sub subtitle {
    my ( $title, $doc ) = @_;

    $doc->appendHeading( 3, $title );
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
    my ( $Self, $doc ) = @_;

    # Generate the report
    my $results = $Self->{'results'};

    section( "Tests Execution Report", $doc );
    $doc->appendParagraph( text => "" );

    $doc->appendParagraph( text => "\n" );
    my $table = $doc->newTable( "Test_Context", 5, 2 );

    my ( $date, $hostname, $uname, $operator ) =
      ( `date`, `hostname`, `uname -a`, `whoami` );
    chomp($date);
    chomp($hostname);
    chomp($uname);
    chomp($operator);
    my $args = join( " ", @{ $Self->{argv} } );

    $doc->fillTableRow( $table, [ 'Date ',                $date ] );
    $doc->fillTableRow( $table, [ 'Generated on ',        $hostname ] );
    $doc->fillTableRow( $table, [ 'Operating system ',    $uname ] );
    $doc->fillTableRow( $table, [ 'Operator ',            $operator ] );
    $doc->fillTableRow( $table, [ 'Generator arguments ', $args ] );

    $doc->copyTableStyle( $table, 'Default_Test_Context' );

    $doc->appendParagraph( text => "" );

    title( "Test Suite Description", $doc );

    if ( defined( $Self->{'test_cases_list'} ) ) {
        $doc->appendParagraph( text =>
"The following description of the test suite comes from the test cases list header."
        );
        $doc->appendParagraph( text => "" );
        my $tcl = $Self->{'test_cases_list'};

        $doc->appendParagraph( text => $tcl->header() );
    }

    title( "Global results", $doc );

    my $table = $doc->appendTable( "Test_Results", 5, 2 );
    my $cnt = 0;
    $doc->cellValue( $table, $cnt,   0, 'Number of tests' );
    $doc->cellValue( $table, $cnt++, 1, $results->{'totalCount'} );
    $doc->cellValue( $table, $cnt,   0, "Tests NOT FOUND " );
    $doc->cellValue( $table, $cnt++, 1, $results->{'result'}->{'NOT_FOUND'} );
    $doc->cellValue( $table, $cnt,   0, "Tests ABORTED " );
    $doc->cellValue( $table, $cnt++, 1, $results->{'result'}->{'ABORTED'} );
    $doc->cellValue( $table, $cnt,   0, "Tests FAILED " );
    $doc->cellValue( $table, $cnt++, 1, $results->{'result'}->{'FAILED'} );
    $doc->cellValue( $table, $cnt,   0, "Tests PASSED " );
    $doc->cellValue( $table, $cnt++, 1, $results->{'result'}->{'PASSED'} );

    $doc->copyTableStyle( $table, 'Default_Test_Results' );

    title( "Global Tests Results", $doc );

    my @testlist = @{ $results->{'tests'} };

    my $table = $doc->appendTable( "TestList", scalar(@testlist) + 1, 5 );

    $doc->cellValue( $table, 0, 0, 'Test Identification' );
    $doc->cellValue( $table, 0, 1, 'Result' );
    $doc->cellValue( $table, 0, 2, 'Sub PASSED' );
    $doc->cellValue( $table, 0, 3, 'Sub FAILED' );
    $doc->cellValue( $table, 0, 4, 'Synopsis' );

    my $cnt = 1;

    # for all the files specified on CLI
    foreach my $tstName (@testlist) {
        my $tst = $results->{'test'}->{$tstName};
        my $note = ( $tst->{'expected'} ) ? "" : "\*";
        $doc->cellValue( $table, $cnt, 0, $tstName );
        $doc->cellValue( $table, $cnt, 1, $tst->globalStatus() . $note );
        $doc->cellValue( $table, $cnt, 2, $tst->passedSubTests() );
        $doc->cellValue( $table, $cnt, 3, $tst->failedSubTests() );
        $doc->cellValue( $table, $cnt, 4, $tst->synopsis() );
        $cnt++;
    }
    $doc->copyTableStyle( $table, 'Default_TestList' );

    # To have the first list repeated on top of each page
    $doc->copyRowToHeader( $table, 0 );
    $doc->deleteRow( $table, 0 );

    $doc->appendParagraph(
        text => "\nTests marked with a \"*\" were not selected." );

}

# ------------------------------------------------------------------------
# routine: generate_traceability
#
#  generate the traceability matrices
# ------------------------------------------------------------------------
sub generate_traceability {
    my ( $Self, $doc ) = @_;

    my $results = $Self->{'results'};

    section( "Requirements Traceability", $doc );

    $doc->appendParagraph(
        text => "Tests per requirements and requirements per test.\n" );

    title( "Tests per requirement", $doc );

    # Tests per requirement
    my @list = sort( @{ $results->{'req_list'} } );
    my $table = $doc->appendTable( "TestsPerReq", scalar(@list) + 1, 3 );
    $doc->cellValue( $table, 0, 0, 'Requirements' );
    $doc->cellValue( $table, 0, 1, ' % ' );
    $doc->cellValue( $table, 0, 2, 'Tests' );
    $doc->copyTableStyle( $table, 'Default_TestsPerReq' );

    my $cnt = 1;
    foreach my $r (@list) {
        my $nb      = scalar( @{ $results->{'requirement'}->{$r} } );
        my $passed  = $results->{'passed'}->{$r};
        my $percent = ( $nb == 0 ) ? 0 : int( ( $passed * 100 ) / $nb );
        $doc->cellValue( $table, $cnt, 0, $r );
        $doc->cellValue( $table, $cnt, 1, $percent );
        $doc->cellValue( $table, $cnt, 2,
            join( ", ", @{ $results->{'requirement'}->{$r} } ) );
        $cnt++;
    }

    # Requirements per test
    title( "Requirements per test", $doc );
    my @list = @{ $results->{'tests'} };
    my $table = $doc->appendTable( "ReqsPerTest", scalar(@list) + 1, 2 );
    $doc->cellValue( $table, 0, 0, 'Test' );
    $doc->cellValue( $table, 0, 1, 'Requirements' );

    $cnt = 1;
    foreach my $tstName (@list) {
        my $tst = $results->{'test'}->{$tstName};

        $doc->cellValue( $table, $cnt, 0, $tstName );
        $doc->cellValue( $table, $cnt, 1, $tst->variable("Requirements") );
        $cnt++;
    }
    $doc->copyTableStyle( $table, 'Default_ReqsPerTest' );
}

# ------------------------------------------------------------------------
# routine: generate_tests
#
#  generate the documentation for each test
# ------------------------------------------------------------------------
sub generate_tests {
    my ( $Self, $doc ) = @_;

    my $results  = $Self->{'results'};
    my $filename = $Self->{'filename'};
    my $outDir   = $Self->{'outputDirectory'};
    my $tcl      = $Self->{'test_cases_list'};

    if ( $tcl->groups() ) {

        # tests per sections
        foreach my $grp ( $tcl->groups() ) {
            section( $grp, $doc );

            # print "group $grp\n";
            foreach my $tst ( $tcl->testsOfGroup($grp) ) {

                # print "\t$tst\n";
                $Self->generate_test( $tst, $doc );
            }
        }
        
        # create an unclassified section
        my @unclassified = ();
        foreach my $tstName ( @{ $results->{'tests'} } ) {
            unless ( $tcl->groupOfTest($tstName) ) {
                push( @unclassified, $tstName );
            }
        }

        # unclassified section
        if (@unclassified) {
            section( "Others Tests Results", $doc );

            # print "unclassified\n";
            foreach my $tstName (@unclassified) {
                $Self->generate_test( $tstName, $doc );
            }
        }
        

    }
    else {

        # No group defined
        section( "Tests Results", $doc );
        foreach my $tstName ( @{ $results->{'tests'} } ) {
            $Self->generate_test( $tstName, $doc );
        }
    }
}

# ------------------------------------------------------------------------
# routine: generate_test
#
#  generate the documentation for one test
# ------------------------------------------------------------------------
sub generate_test {
    my ( $Self, $tstName, $doc ) = @_;

    my $results  = $Self->{'results'};
    my $filename = $Self->{'filename'};
    my $outDir   = $Self->{'outputDirectory'};

    # test title
    title( "Test " . $tstName, $doc );

    # print "test $tstName\n";

    # test results extracted by the parser from assertion checks
    my $tst = $results->{'test'}->{$tstName};
    unless ($tst) {
        $doc->appendParagraph( text => "No results found for this test." );
        return;
    }
    $doc->appendParagraph( text => $tst->synopsis() );
    $doc->appendParagraph( text => "\n" );

    subtitle( "Result", $doc );
    my $table = $doc->appendTable( "Results\." . $tstName, 8, 2 );
    my $cnt = 0;
    $doc->cellValue( $table, $cnt,   0, 'Test ID ' );
    $doc->cellValue( $table, $cnt++, 1, $tstName );
    $doc->cellValue( $table, $cnt,   0, 'Global result ' );
    $doc->cellValue( $table, $cnt++, 1, $tst->globalStatus() );
    $doc->cellValue( $table, $cnt,   0, "PASSED sub-tests " );
    $doc->cellValue( $table, $cnt++, 1, $tst->passedSubTests() );
    $doc->cellValue( $table, $cnt,   0, "FAILED sub-tests " );
    $doc->cellValue( $table, $cnt++, 1, $tst->failedSubTests() );
    $doc->cellValue( $table, $cnt,   0, "Log file " );
    $doc->cellValue( $table, $cnt++, 1, $tst->filename() );
    $doc->cellValue( $table, $cnt,   0, "Execution start time " );
    $doc->cellValue( $table, $cnt++, 1, gmt( $tst->startTime() ) );
    $doc->cellValue( $table, $cnt,   0, "Execution end time " );
    $doc->cellValue( $table, $cnt++, 1, gmt( $tst->endTime() ) );

#        $doc->cellValue( $table, $cnt, 0,  "Command line arguments ");
#        $doc->cellValue( $table, $cnt++, 1, $tst->variable("Command line Arguments"));
    $doc->cellValue( $table, $cnt,   0, "Requirements " );
    $doc->cellValue( $table, $cnt++, 1, $tst->variable("Requirements") );
    $doc->copyTableStyle( $table, 'Default_Test_Context' );

    # Test documentation, declared by the test itself
    my $tstdoc = $tst->doc();
    if ($tstdoc) {
        subtitle( "Documentation", $doc );
        $doc->appendParagraph(
            text => "\t" . join( "\n\t", split( /\n/, $tstdoc ) ) );
    }

    # Extracted from the counter values
    $tstdoc = $tst->counters();
    if ($tstdoc) {

        # single line counters, create a single table for all of them
        my @list = $tst->counter_list();

        if (@list) {
            subtitle( "Counters", $doc );
            my $table =
              $doc->appendTable( "Counters\.$tstName", scalar(@list) + 1, 2 );
            $doc->cellValue( $table, 0, 0, 'Counter' );
            $doc->cellValue( $table, 0, 1, 'Value' );

            my $n = 0;
            foreach my $cnt (@list) {

                # print "counter $cnt=" . $tst->counter_value($cnt) . "\n";
                my @col_list = $tst->table_columns($cnt);
                my $col      = $col_list[1];
                $doc->cellValue( $table, $n + 1, 0, $col );
                $doc->cellValue( $table, $n + 1, 1,
                    $tst->table_value( $cnt, $col, 0 ) );
                $n++;
            }
            $doc->copyTableStyle( $table, 'Default_Test_Context' );
            $doc->appendParagraph( text => "" );
        }

        return;
        
        # multiple lines tables, one table for each of them
        foreach my $tbl ( $tst->table_list() ) {

            subtitle( "Table $tbl", $doc );
            my $size     = $tst->table_size($tbl);
            my @col_list = $tst->table_columns($tbl);
            my $table    = $doc->appendTable( $tbl . '.' . $tstName,
                $size + 1, scalar(@col_list) );
            my $n = 0;
            foreach my $col ( $tst->table_columns($tbl) ) {
                $doc->cellValue( $table, 0, $n, $col );
                $n++;
            }

            my $line = 1;
            for ( my $i = 0 ; $i < $tst->table_size($tbl) ; $i++ ) {
                my $n = 0;
                foreach my $col ( $tst->table_columns($tbl) ) {
                    $doc->cellValue( $table, $line, $n,
                        $tst->table_value( $tbl, $col, $i ) );
                    $n++;
                }
                $line++;
            }
            $doc->appendParagraph( text => "" );
        }

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

    # Create an OpenOffice document
    my $doc = new Doc::DocGen(
        'template' => $Self->{'template'},
        'output'   => $filename
    );
    $Self->{'doc'} = $doc;

    # Set some meta data
    $doc->title('Software Tests Report');

    # $doc->subject('CPE 2.3STD5 Test Plan');
    $doc->description('This document contains the software tests report.');
    $doc->keywords( 'STR', 'Documentation', 'Tests', 'Validation' );

    $Self->generate_global($doc);
    $Self->generate_traceability($doc);
    $Self->generate_tests($doc);

    # Close and save
    $doc->appendParagraph( text => "" );
    $doc->appendParagraph( style => 'Centre', text => "- End of document -" );

    $doc->save($filename);
    print "test report $filename generated\n";
}

1;
