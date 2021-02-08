# ----------------------------------------------------------------------------
#
# Title: Class Reporters::List
#
# Name:
#
#    package Reporters::List
#
# Abstract:
#
#    Test case list
#    Handle the attributes of a test case list.
#    Currently it only support one format, the csv.
# ----------------------------------------------------------------------------
package Reporters::List;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Exporter;
use Log::Log4perl;
use Data::Dumper;
use CSVFile;
use Reporters::Test;

$VERSION = 1;

@ISA = qw(CSVFile);

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    my %attr = @_;

    $Self->{allTests} = [];
    $Self->{testId}   = "testId";
    $Self->{'tests'}  = {};

    die "\"titleLine\" attribute is mandatory for Reporters::List objects"
      unless ( exists( $attr{'titleLine'} ) );

    # Call the parent initialization first
    $Self->CSVFile::_init(@_);

    # Others initialisation

    # register columns and multiple
    foreach my $col ( @{ $Self->{'flag'} } ) {
        $Self->{Logger}->trace( "flag: " . $col );
        $Self->{isFlag}->{$col} = 1;
    }

    foreach my $col ( @{ $Self->{'parameter'} } ) {
        $Self->{Logger}->trace( "parameter: " . $col );
        $Self->{isParameter}->{$col} = 1;
    }
    foreach my $col ( @{ $Self->{'argument'} } ) {
        $Self->{Logger}->trace( "argument: " . $col );
        $Self->{isArgument}->{$col} = 1;
    }
    foreach my $col ( @{ $Self->{'csv'} } ) {
        $Self->{Logger}->trace( "csv: \'" . $col . "\'" );
        $Self->{isMultiple}->{$col} = 1;
    }
}

# ------------------------------------------------------------------------
# routine: removeQuotes
#
#    remove quotes around a string
# ------------------------------------------------------------------------
sub removeQuotes {
    my ($str) = @_;

    if ( $str =~ /\"(.*)\"/ ) {
        return $1;
    }
    else {
        return $str;
    }
}

# ----------------------------------------------------------------------------
# method: load
#
#
# ----------------------------------------------------------------------------
sub load {
    my ( $Self, $filename ) = @_;

    TestTools::CSVFile::load(@_);

    my $tid_idx = $Self->column( $Self->{testId} );
    die "No column named "
      . $Self->{testId}
      . " at line "
      . $Self->titleLine()
      . " found to identify the tests"
      unless ( $tid_idx > -1 );

    $Self->{'Logger'}->trace("$filename loaded, lines=" . $Self->lineNumber());    
    for ( my $i = $Self->titleLine() + 1 ; $i <= $Self->lineNumber() ; $i++ ) {
        my $tst = $Self->cell( $i, $tid_idx );
        $tst = removeQuotes($tst);
        next if ( $tst eq "" );
        push( @{ $Self->{allTests} }, $tst );
        $Self->{'tests'}->{$tst} =
          new Reporters::Test( "test_list" => $Self, line => $i );
    }
}

# ------------------------------------------------------------------------
# method: isParameter
#
# returns true when the column is a scalar parameter
# ------------------------------------------------------------------------
sub isParameter {
    my ( $Self, $name ) = @_;
    return exists( $Self->{isParameter}->{$name} );
}

# ------------------------------------------------------------------------
# method: isArgument
#
# returns true when the column is a scalar parameter
# ------------------------------------------------------------------------
sub isArgument {
    my ( $Self, $name ) = @_;
    return exists( $Self->{isArgument}->{$name} );
}

# ------------------------------------------------------------------------
# method: isMultiple
#
# returns true when the column is a csv parameter
# ------------------------------------------------------------------------
sub isMultiple {
    my ( $Self, $name ) = @_;
    return exists( $Self->{isMultiple}->{$name} );
}

# ------------------------------------------------------------------------
# method: isFlag
#
# returns true when the column is a flag parameter
# ------------------------------------------------------------------------
sub isFlag {
    my ( $Self, $name ) = @_;
    return exists( $Self->{isFlag}->{$name} );
}

# ----------------------------------------------------------------------------
# method: allTests
#
#    Returns:
#
#    The list of all testId
# ----------------------------------------------------------------------------
sub allTests {
    my ($Self) = @_;

    $Self->{Logger}
      ->trace( "allTests = (" . join( ", ", @{ $Self->{allTests} } ) . ")" );
    return @{ $Self->{allTests} };
}

# ----------------------------------------------------------------------------
# method: selectedTests
#
#    Returns:
#
#    The list of all selected tests
# ----------------------------------------------------------------------------
sub selectedTests {
    my ($Self) = @_;

    if ( exists( $Self->{'selector'} ) && defined( $Self->{'selector'} ) ) {
        $Self->{'Logger'}->trace(
            "selectedTests with selector, returns a selection of the tests");
        my @list = ();
        foreach my $tst ( $Self->allTests() ) {

            # print "$tst (", $Self->test($tst)->select(), ")\n";
            if ( $Self->test($tst)->select() ) {
                push( @list, $tst );
            }
        }
        return @list;
    }
    else {
        $Self->{'Logger'}
          ->trace("selectedTests, no selector returns all tests");
        return $Self->allTests();
    }
}

# ----------------------------------------------------------------------------
# method: addTest
#
#    Add a new test to the test case list
#
#    Exception:
#    Die when a test with the same IT is already present.
# ----------------------------------------------------------------------------
sub addTest {
    my ( $Self, $t ) = @_;
}

# ------------------------------------------------------------------------
# method: dump
#
# print an ASCII representation of the object
# ------------------------------------------------------------------------
sub dump {
    my $Self = shift;

    print Dumper($Self), "\n";
}

# ----------------------------------------------------------------------------
# method: test
#
# Parameters:
#   $t - test id
#
# Returns: the test
# ----------------------------------------------------------------------------
sub test {
    my ( $Self, $t ) = @_;

    return $Self->{'tests'}->{$t};
}

# ----------------------------------------------------------------------------
# method: synopsis
#
# Returns: the synopsis column name
# ----------------------------------------------------------------------------
sub synopsis {
    my ( $Self, $t ) = @_;

    return $Self->{'synopsis'};
}

# ----------------------------------------------------------------------------
# method: selector
#
# Returns: the selector column name
# ----------------------------------------------------------------------------
sub selector {
    my ( $Self, $t ) = @_;

    return $Self->{'selector'};
}

# ----------------------------------------------------------------------------
# method: testId
#
# Returns: the testId column name
# ----------------------------------------------------------------------------
sub testId {
    my ( $Self, $t ) = @_;

    return $Self->{'testId'};
}

# ----------------------------------------------------------------------------
# method: testSynopsis
#
# Returns: the test synopsis
# ----------------------------------------------------------------------------
sub testSynopsis {
    my ( $Self, $t ) = @_;

    return removeQuotes( $Self->cell_by_name( $t, $Self->synopsis() ) );
}

# ----------------------------------------------------------------------------
# method: script
#
# Generate a shell script
# ----------------------------------------------------------------------------
sub script {
    my ( $Self, $filename ) = @_;

    my $fd;
    if ($filename) {
        open( $fd, "> $filename" ) or die("cannot open file $filename : $!");
    }
    else {
        $fd = *STDOUT;
    }
    print $fd "# ", '-' x 80, "\n";
    print $fd "# ", join( "\n# ", split( "\n", $Self->header() ) ), "\n";
    print $fd "# ", '-' x 80, "\n";
    print $fd "# selected = " . join( ", ", $Self->selectedTests() ) . "\n";
    foreach my $tst ( $Self->selectedTests() ) {
        if ($tst) {
            print $fd "\n# $tst: ", $Self->test($tst)->synopsis(), "\n";
            print $fd $Self->test($tst)->cmdLine(), "\n";
        }
    }
    print $fd "# ", '-' x 80, "\n";

    if ($filename) {
        close $fd;
    }
}

# ----------------------------------------------------------------------------
# method: groups
#
#    Returns: The list of all test categories
# ----------------------------------------------------------------------------
sub groups {
    my ($Self) = @_;

    my @list          = ();
    my $current_group = "Tests without category";
    $Self->{'testsByGroup'}->{$current_group} = [];
    if ( $Self->{'group'} ne "" ) {
        my $groupIndex = $Self->column( $Self->{'group'} );
        die "Group column " . $Self->{'group'} . " does not exist."
          if ( $groupIndex < 0 );

        my $tid_idx = $Self->column( $Self->{testId} );

        for (
            my $line = $Self->titleLine() + 1 ;
            $line <= $Self->lineNumber() ;
            $line++
          )
        {
            my $grp = $Self->cell( $line, $groupIndex );
            if ($grp) {
                push( @list, $grp );
                $current_group = $grp;
                $Self->{'testsByGroup'}->{$grp} = [];
            }

            my $tst = $Self->cell( $line, $tid_idx );
            if ($tst) {
                push( @{ $Self->{'testsByGroup'}->{$current_group} }, $tst );
                $Self->{'groupOfTest'}->{$tst} = $current_group;
            }
        }
    }
    return @list;
}

# ----------------------------------------------------------------------------
# method: testsOfGroup
#
#    Returns: The list of all test inside a category
# ----------------------------------------------------------------------------
sub testsOfGroup {
    my ( $Self, $group ) = @_;

    if ( exists( $Self->{'testsByGroup'}->{$group} ) ) {
        my @grp = @{ $Self->{'testsByGroup'}->{$group} };
        return @grp;
    }
    return ();
}

sub groupOfTest {
    my ( $Self, $tst ) = @_;

    if ( exists( $Self->{'groupOfTest'}->{$tst} ) ) {
        return $Self->{'groupOfTest'}->{$tst};
    }
    else {
        return undef;
    }

}

1;
