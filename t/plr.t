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

use Plr;

# Log::Log4perl->init("$ENV{'FTF'}/conf/log4perl.conf");

print "# Plr unit test\n";

my $p = new Plr (a => -1.0, b => 2.0, c => 3.0);


ok ($p, "Object creation");
is ($p->attr(3), 3, "Attribute initialization");
is ($p->roattr(), undef, "Attribute value");
print $p->vz(1), "\n";
