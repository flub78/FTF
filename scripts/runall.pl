# ------------------------------------------------------------------------
# Title:  Tests Execution Controler
#
# File - script/runtst.pl
#
# Abstract:
# 
#    This script control the execution of several tests which use 
#    Test::More (Perl tests) and produce a global test report. 
#    It takes a list of file and directories and will run all
#    the specified files and all the files found in the directories.
#
#    See the <Script> module documentation for the detail
#    of accepted options.
# ------------------------------------------------------------------------
package RunTst;

use strict;
use lib "$ENV{'PERL_TEST_TOOLS_PATH'}/lib";
use TestTools::Script;
use File::Find;
use Test::Harness;
use TestTools::Conf::ScriptConfig qw (GetOnlineHelp GetOption Load NumberOfElements Initialize);


use vars qw($VERSION @ISA @EXPORT);
use Exporter;

$VERSION = 1;
@ISA = qw(TestTools::Script);

# This hash table is used to declare and define options.
my %OptionSet = (
    pattern   =>  {
	type => "string",
	description => "file matching pattern",
	default => 0
    },
);

# ########################################################################
my $script;
my @test_list = ();

# ------------------------------------------------------------------------
# routine: treatfile
#
# Process each file. Warning it is not an object method because 
# find does not expect a reference as first parameter.  The $Self
# variable is set to emulate it. 
#
# Parameters:
#    filename - file to treat
# ------------------------------------------------------------------------
sub treatfile {

    my $filename = $_;
    my $Self = $script;

    return if (-d $filename);

    my $pattern = TestTools::Conf::ScriptConfig::GetOption('pattern');
    my $name = $File::Find::name;

    if ($name eq "") {
	# a file was specified, direct call
	$name = $filename;
    } else {
	# indirect call by find
    }

    if ($pattern) {
	$Self->info("evaluating " . $name . " with " . $pattern);
	# pattern has been specified we check the match
	if ($name =~/$pattern/) {
	    $Self->info("match ");
	    push @test_list, $name;
	}
    } else {
	# process all files
	$Self->info("processing " . $name);
	push @test_list, $name;
    }
}


# ------------------------------------------------------------------------
# routine: run
#
#  Scrip main method.
# ------------------------------------------------------------------------
sub run {
    my $Self = shift;
    
    my $name = TestTools::Script::basename();
    $Self->info("starting $name");

    # for all the files specified on CLI
    foreach my $arg (@ARGV) {
	while (glob($arg)) {
	    treatfile($_) if (-f $_);
	    File::Find::find(\&treatfile, $_) if (-d $_);
	}
    }

    Test::Harness::runtests(@test_list);
    $Self->info("$name completed");
}

# ------------------------------------------------------------------------
# read CLI and configuration file
my @argv = @ARGV;
Initialize(TestTools::Script::configurationFilename(),
    \%OptionSet, TestTools::Script::optionSet());
$script = new RunTst();
$script->run();

