# ------------------------------------------------------------------------
# Title:  TestMemonitor
#
# File - TestMemonitor.pl
# Version - 1.0
#
# Abstract:
#
#    This is the memonitor unitary test.
# ------------------------------------------------------------------------
package TestMemonitor;

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

# ------------------------------------------------------------------------
# method: test
#
# Test a memory monitor
# ------------------------------------------------------------------------
sub test {
    my ( $Self, $mon, $comment ) = @_;

    $Self->info($comment);

    #$mon->dump();

    my $bigstr = "0123456789ABCDEF0123456789ABCDEF";

    for ( my $i = 0 ; $i < 10 ; $i++ ) {
        my $mem = $mon->measure();
        print $mon->measureCount(), " ", $mon->{'peakIndex'}, ": ", "mem = ",
          $mem, " ", ", highwatermark = ", $mon->memoryPeak(),    
          ", peak reach at = ", $mon->peakPercentage(), "\n";
        sleep(1);
        print "value=", $mon->value(),
              ", value(-10)=", $mon->value(-10),  
              ", value(1)=", $mon->value(1),  
        "\n";
        print "delta v = ", $mon->value() - $mon->value(1), "\n";
        print "delta t = ", $mon->time() - $mon->time(1), "\n";
        $bigstr .= $bigstr;        
    }

    $bigstr = "";
    for ( my $i = 0 ; $i < 30 ; $i++ ) {
        my $mem = $mon->measure();
        sleep(1);
        print $mon->measureCount(), " ", $mon->{'peakIndex'}, ": ", "mem = ",
          $mem, " ", ", highwatermark = ", $mon->memoryPeak(),
          ", peak reach at = ", $mon->peakPercentage(), " %\n";
        print "value=", $mon->value(),
              ", value(-10)=", $mon->value(-10),  
              ", value(1)=", $mon->value(1),  
        "\n";
        print "delta v = ", $mon->value() - $mon->value(1), "\n";
        print "delta t = ", $mon->time() - $mon->time(1), "\n";
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

    my $mon = new TestTools::Utilities::Memonitor( pid => $$, size => 7 );
    ok( $mon, "Memonitor creation" );
    my $mon2 =
      new TestTools::Utilities::Memonitor( pid => "memonitor", "use_ps" => 0 );
    ok( $mon2, "ps Memonitor creation" );

    $Self->test( $mon,  "local memory monitor" );
    print Dumper($mon), "\n";
    $Self->test( $mon2, "ps memory monitor" );
    print Dumper($mon2), "\n";
}

# ------------------------------------------------------------------------
# Variable: test
# my Test local instance.
my $test = new TestMemonitor( keywords => \@KEYWORDS );

Initialize( TestTools::Script::configurationFilename(),
    \%OptionSet, TestTools::Test::optionSet() );

$test->run();

# print Dumper($test);

