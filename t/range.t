# ------------------------------------------------------------------------
# Title:  Range Unit Test
#
# File - range.t
# Version - 1.0
#
# Abstract:
#
#    Unitary test for the range class
# ------------------------------------------------------------------------
package RangeTest;

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
use Range;

my $config     = new ScriptConfiguration('scheme'     => TEST);

# ------------------------------------------------------------------------
# method: belong
#
# first subtest
# ------------------------------------------------------------------------
sub belong {
    my $Self = shift;

    my $it = new Range();
    ok(($it->toString() eq ""), "null range " . $it);
    ok ($it->isContinuous(), "null is continuous");


    $it = new Range( 5, 10);
    ok( $it, "simple range" );
    ok ($it->isContinuous(), "simple is continuous");
    
    ok (!$it->belongTo(4), "4 does not belong to 5 .. 10");
    ok ($it->belongTo(5), "5 belongs to 5 .. 10");
    ok ($it->belongTo(6), "6 belongs to 5 .. 10");
    ok ($it->belongTo(9), "9 belongs to 5 .. 10");
    ok ($it->belongTo(10), "10 belongs to 5 .. 10");
    ok (!$it->belongTo(11), "11 does not belong to 5 .. 10");

    # isContinuous and belongTo
    $it = new Range( 101, 101, 120, 199, 10, 100, 200, 300 );
    ok( $it, "multiply range" );
    ok (!$it->isContinuous(), "multiple is not continuous");
    ok (!$it->belongTo(9), "9 does not belong to 10..101, 120..300");
    ok ($it->belongTo(10), "10 belongs to 10..101, 120..300");
    ok ($it->belongTo(101), "101 belongs to 10..101, 120..300");
    ok (!$it->belongTo(102), "102 does not belong to 10..101, 120..300");
    ok (!$it->belongTo(119), "119 does not belong to 10..101, 120..300");
    ok ($it->belongTo(120), "120 belongs to 10..101, 120..300");
    ok ($it->belongTo(300), "300 belongs to 10..101, 120..300");
    ok (!$it->belongTo(301), "301 does not belong to 10..101, 120..300");

    my $rg = new Range(10, 101, 120, 300);
    # ok ($it->equal($rg), "check equality cas 1");
    ok ($it == $rg, "check equality cas 1");
    $rg = new Range(120, 300, 10, 101);
    # ok (($it->equal($rg)), "check equality cas 2");
    ok (($it == $rg), "check equality cas 2");
    
    $rg = new Range(1, 101, 120, 300);
    # ok (!$it->equal($rg), "check inequality cas 1");
    ok (($it != $rg), "check inequality cas 1 :\"" . (($it != $rg)) ."\"");
    $rg = new Range(120, 300);
    ok (!$it->equal($rg), "check inequality cas 2");
    my $rg = new Range(10, 300);
    ok (!$it->equal($rg), "check inequality cas 3");
}


# ------------------------------------------------------------------------
# method: check_operation
#
# operations subtest
#
# Parameters:
#   $left - left operande range
#   $op - 'union' | 'intersection'
#   $right - right operande
#   $expected - expected result
#   $comment - subtest description
# ------------------------------------------------------------------------
sub check_operation {
    my ($Self, $left, $op, $right, $expected, $comment) = @_;
    
    my $msg = "checking " . $left . " " . $op . " " . $right . " == " . $expected . " " . $comment;
    # print '-' x 80, "\n";
    # print "$msg\n";
    
    my $actual_res;
    if ($op eq "union") {
        $actual_res = $left + $right;
    } else {
        $actual_res = $left * $right;        
    }
    # print ">>> result = ", $actual_res, "\n\n";
    ok ($actual_res == $expected, $msg);
}

# ------------------------------------------------------------------------
# method: check_intersection
#
# operations subtest
# ------------------------------------------------------------------------
sub check_intersection {
    my $Self = shift;
        
    # Union and intersection
    my $r0 = new Range();
    my $r1 = new Range(100, 200);
    my $r2 = new Range(300, 400);
    my $r3 = new Range(100, 200, 300, 400);
    my $r4 = new Range(120, 180, 320, 380);
    my $r5 = new Range(150, 250, 350, 450);
    my $r6 = new Range(150, 250, 350, 450);
    my $r7 = new Range(150, 200, 350, 400);
    my $r8 = new Range (150, 150, 350, 350);
    my $r9 = new Range (100, 100, 400, 400);
    my $r10 = new Range (99, 100, 399, 399);
    my $r11 = new Range (100, 100);

    $Self->check_operation ($r1, 'intersection', $r2, $r0, "simple intersection w/o overlap");
    $Self->check_operation ($r3, 'intersection', $r3, $r3, "self intersection");
    $Self->check_operation ($r9, 'intersection', $r9, $r9, "self intersection singles");
    $Self->check_operation ($r3, 'intersection', $r4, $r4, "included intersection");
    $Self->check_operation ($r3, 'intersection', $r5, $r7, "imbricateded intersection");
    $Self->check_operation ($r3, 'intersection', $r8, $r8, "singles intersection");
    $Self->check_operation ($r3, 'intersection', $r9, $r9, "singles intersection 2");

    $Self->check_operation ($r10, 'intersection', $r9, $r11, "boundaries intersection");
}

# ------------------------------------------------------------------------
# method: operations
#
# operations subtest
# ------------------------------------------------------------------------
sub check_union {
    my $Self = shift;
        
    # Union 
    my $r0 = new Range();
    my $r1 = new Range(100, 200);
    my $r2 = new Range(300, 400);
    my $r3 = new Range(100, 200, 300, 400);
    my $r4 = new Range(100, 500);
    my $r5 = new Range(100, 300);
    my $r6 = new Range(200, 400);
    my $r7 = new Range(100, 400);
    my $r8 = new Range(99, 99);
    my $r9 = new Range(100, 100);
    my $r10 = new Range(101, 101);
    my $r10x = new Range(0x65, 0x65);
    
    my $r11 = new Range(99, 200, 300, 400);
    my $r12 = new Range(10, 20, 50, 100);
    my $r13 = new Range(10, 20, 50, 101);
    my $r12x = new Range(0x0A, 0x14, 0x32, 0x64);
    my $r13x = new Range(0x0a, 0x14, 50, 101);
    my $r14 = new Range(201, 299, 401, 500);
    
    $Self->check_operation ($r1, 'union', $r2, $r3, "simple union w/o overlap");
    $Self->check_operation ($r3, 'union', $r3, $r3, "self union");
    $Self->check_operation ($r4, 'union', $r2, $r4, "included union");
    $Self->check_operation ($r5, 'union', $r6, $r7, "overlapping union");

    $Self->check_operation ($r3, 'union', $r8, $r11, "short before union");
    $Self->check_operation ($r3, 'union', $r9, $r3, "short limit union");
    $Self->check_operation ($r3, 'union', $r10, $r3, "short limit+1 union");

    $Self->check_operation ($r12, 'union', $r8, $r12, "short limit-1 union");
    $Self->check_operation ($r12, 'union', $r9, $r12, "short limit union, case 2");
    $Self->check_operation ($r12, 'union', $r10, $r13, "short limit union, case 3");
    $Self->check_operation ($r12x, 'union', $r10x, $r13x, "short limit union, hexa");

    $Self->check_operation ($r3, 'union', $r14, $r4, "coincidence");
}

# ------------------------------------------------------------------------
# method: operations
#
# operations subtest
# ------------------------------------------------------------------------
sub check_included {
    my $Self = shift;
    
    my $it = new Range(100, 200, 300, 400, 500, 600);
    my $rg = new Range (110, 120, 130, 140);
    
    ok ($it->isIncluded($rg), "110, 120, 130, 140 included in 100, 200, 300, 400, 500, 600");
    ok ($it->isIncluded($it), "100, 200, 300, 400, 500, 600 included in itself");
    $rg = new Range (99, 99);
    ok (!($it->isIncluded($rg)), "99, 99 not included in 100, 200, 300, 400, 500, 600");

    $rg = new Range (200, 400);
    ok (!($it->isIncluded($rg)), "200..400 not included in 100, 200, 300, 400, 500, 600");
    $rg = new Range (601, 601);
    ok (!($it->isIncluded($rg)), "601 601 not included in 100, 200, 300, 400, 500, 600");
}
    
# ------------------------------------------------------------------------
# method: check_overlap
#
# operations subtest
# ------------------------------------------------------------------------
sub check_overlap {
    my $Self = shift;
    
    my $r0 = new Range();
    my $r1 = new Range(100, 200);
    my $r2 = new Range(150, 400);
    my $r3 = new Range(100, 200, 300, 400);
    my $r4 = new Range(300, 500);
    my $r5 = new Range(201, 299, 401, 500);
    my $r6 = new Range(201, 299, 400, 500);
    my $r7 = new Range(500, 500);

    ok ($r1->overlap($r2), "overlap cas 1");    
    ok ($r2->overlap($r1), "overlap cas 2");    
    ok (!$r1->overlap($r4), "overlap cas 3");    
    ok (!$r4->overlap($r1), "overlap cas 4");    
    ok (!$r3->overlap($r5), "overlap cas 5");    
    ok (!$r5->overlap($r3), "overlap cas 6");    
    ok ($r6->overlap($r3), "overlap cas 7");    
    ok ($r3->overlap($r6), "overlap cas 8");    

    ok ($r7->overlap($r6), "overlap cas 9");    
    ok ($r6->overlap($r7), "overlap cas 10");    
}        


# ------------------------------------------------------------------------
# method: check_string_range
#
# CHeck that ranges can be expressed as strings
# ------------------------------------------------------------------------
sub check_string_range {
    my $Self = shift;
    
    my $r1 = new Range(100, 200);
    my $r2 = new Range("100 .. 200");
    my $r3 = new Range("0x64 .. 0xC8");
    
    my $r4 = new Range(100, 200, 300, 400);
    my $r5 = new Range("100..200, 300..400");
    my $r6 = new Range ("0x64 .. 0xC8, 300 .. 0x190");
    
    ok ($r1->equal ($r2), "simple range as string");
    ok ($r2->equal ($r3), "simple range as hexadecimal string");
    
    ok ($r4->equal($r5), "complex range as string");
    ok ($r5->equal($r6), "complex range as hexadecimal string");    
}

# ------------------------------------------------------------------------
# method: TestMain
#
# Test main routine. It is this method which is executed several times
# when the *-iteration* parameter is more than 1.
# ------------------------------------------------------------------------
sub TestMain {
      my $Self = shift;

      $Self->belong();
      $Self->check_union();
      $Self->check_intersection();
      $Self->check_included();
      $Self->check_overlap();
      $Self->check_string_range();
}

# ------------------------------------------------------------------------
my $test = new RangeTest();
$test->run();


