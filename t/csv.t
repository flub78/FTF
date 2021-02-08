# ------------------------------------------------------------------------
# Title:  CSVFile Unit Test
#
# Abstract:
#
#    Comma separated value file unit test
# ------------------------------------------------------------------------
package TestTemplate;

use strict;
use lib "$ENV{'FTF'}/lib";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Test;

$VERSION = 1;
@ISA     = qw(Test);

# Test::More is only used to test Perl modules.
use Test::More qw( no_plan );
use Data::Dumper;
use ExecutionContext;
use ScriptConfiguration;

use CSVFile;

# ------------------------------------------------------------------------
# method: subtest_1
#
# first subtest
# ------------------------------------------------------------------------
sub existing {
    my $Self = shift;

    # First subtest
    my $filename = $ENV{'FTF'} . "/t/test_suite.csv";
    my $csv = new CSVFile(filename => $filename);
    ok( $csv, "csv creation" );
    is ($csv->filename(), $filename, "filename accessor");
    is ($csv->lineNumber(), 20, "\$csv->lineNumber()");
    is ($csv->line(1), "Example of test suite;;;;;;;;;;;", "first line");
    my $val = "Another example of test suite;;;;;;;;;;;";
    is ($csv->line(1, $val), $val, "change first line");
    is ($csv->line(1), $val, "modified first line");
    
    my $copie = $filename . ".cpy";
    unlink ($copie);
    ok (!(-f $copie), "copie erased");
    $csv->save($copie);
    ok ((-f $copie), "copie exist");
    
    # reload copie
    my $csv2 = new CSVFile(filename => $copie, titleLine => 5);
    is ($csv2->line(1), $val, "modified first line in copy");

    is ($csv->line(3), $csv2->line(3), "unmodified lines are equal");
    
    my $ln = $csv->lineNumber();
    is ($csv->line($ln+1), undef, "last line + 1");
    
    is ($csv->titleLine(), -1, "titleLine");
    is ($csv2->titleLine(), 5, "titleLine");
    
    is ($csv->title(), undef, "title without titleLine");
    is (join (", ", $csv2->title()), "Engine, Scenario, TestId, Synopsis, output, fail, iteration, perf, memory, host, selected, requirements", "title");
    
    is ($csv2->colNumber(), 12, "colNumber");
    is ($csv2->colName(0), "Engine", "colName[0]");
    is ($csv2->colName(11), "requirements", "colName[11]");
    is ($csv2->colName(12), undef, "colName[12]");
    
    print $csv2->dump();
    
    print "value=\"",
    join (", ", $csv2->title())
    , "\"\n";
}

# ------------------------------------------------------------------------
# method: by_name
#
# first subtest
# ------------------------------------------------------------------------
sub by_name {
    my $Self = shift;

    # First subtest
    my $filename = $ENV{'FTF'} . "/t/test_suite.csv";
    my $csv = new CSVFile (
        filename => $filename,
        titleLine => 5,
        lineName => "TestId");
        
    # print Dumper($csv), "\n";
        
    is ($csv->titleLine(), 5, "titleLine");
    print $csv->header();
    print "| ";
    foreach my $col ($csv->title()) {
        print "$col |";        
    }
    print "\n";

    my $cnt = 0;
    print "| ";
    foreach my $col ($csv->title()) {
        print $csv->title($cnt), " |";
        $cnt++;        
    }
    print "\n";
    
    $cnt = 0;
    foreach my $ln ($csv->lineNames()) {
        print "$ln ", $csv->lineNames($cnt), "\n";
        $cnt++;
    }

    foreach my $ln ($csv->lineNames()) {
        foreach my $col ($csv->title()) {
            my $str = $csv->cell_by_name($ln, $col) ?
                $csv->cell_by_name($ln, $col) : "";
            print $str, ", ";
        }
        print "\n";
    }    
}

# ------------------------------------------------------------------------
# method: TestMain
#
# Test main routine. It is this method which is executed several times
# when the *-iteration* parameter is more than 1.
# ------------------------------------------------------------------------
sub TestMain {
    my $Self = shift;
    $Self->info("TestMain");

    $Self->existing();
    $Self->by_name();
}

# ------------------------------------------------------------------------
my $config     = new ScriptConfiguration(
    'scheme'     => TEST,
);

my $testid = ($config->value('testId')) ?
   $config->value('testId') :
   ExecutionContext::basename();

# Variable: test
my $test = new TestTemplate(
    loggerName   => "Tests",
    testId => $testid
);

$test->doc( "TestId = $testid");
$test->run();


