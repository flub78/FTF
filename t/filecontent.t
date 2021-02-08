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

use FileContent;
use UnixCommands;

# Log::Log4perl->init("$ENV{'FTF'}/conf/log4perl.conf");

print "# FileContent unit test\n";
my $msg1 = "Elle souffle!!!\n";
my $filename = "testfile.txt";
writeFile($filename, $msg1);

my $msg2 = readFile ($filename);

is ($msg1, $msg2, "same string after reading");

my $msg3 = "Hello world";
writeFile($filename, $msg3);
$msg2 = readFile ($filename);

is ($msg3, $msg2, "same string after reading");


