# ------------------------------------------------------------------------
# Title:  Perl Module Unit Test Template
#
# Source - <file:../perltest.t.html>
# Version - 1.0
#
# Abstract:
#
#    This is a minimal perl module test template. It is a pure Perl
#    script which does not use any service of the toolbox.
#    You can notice how the test description is embedeed in comments
#    to have the test sheets extracted directly from the test with
#    *NaturalDocs*
#
# Execution:
#
#    > perl perltest.t
#
# Acceptation criteria:
#
#    It is a self-reporting tests which uses the Test::More Perl
#    module for reporting. If the test fails it is reported on STDOUT.
#
# Output:
# (start code)
#perl perltest.t
## Class unit testok 1 - Object creation
#ok 2 - Attribute initialization
#ok 3 - Attribute value
#1..3
# (end)
# ------------------------------------------------------------------------
use strict;
use Test::More qw( no_plan );
use lib "$ENV{'FTF'}/lib";
use lib "$ENV{'FTF'}/templates";
use Log::Log4perl qw(:easy);

use Sets;

# Log::Log4perl->init("$ENV{'FTF'}/conf/log4perl.conf");

print "# Class unit test\n";

my @list = ();
is (@list, 0, "size of an empty list");

add_unique (\@list, "un");
is (@list, 1, "size after add_unique");
add_unique (\@list, "deux");
add_unique (\@list, "un");
add_unique (\@list, "trois");
is (@list, 3, "size after a while");
is (found (\@list, "un"), 1, "un found");
is (found (\@list, "deux"), 1, "deux found");
is (found (\@list, "trois"), 1, "trois found");
is (found (\@list, "quatre"), 0, "quatre not");

my @list2 = ('cinq', 'six');

my @list3 = union(\@list, \@list2);
print join(", ", @list3), "\n";

my @list4 = intersection (\@list3, ['trois', 'cinq']);
print join(", ", @list4), "\n";

ok (equals([], []), "empty list equality" );
ok (equals([1, 2, 3], [3, 1, 2]), "non empty list equality" );
ok (!equals([1, 2, 3], [3, 1]), "inequality" );
ok (!equals([1, 2], [3, 1, 2]), "inequality 2" );
