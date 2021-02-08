#!/bin/sh
#! -*- perl -*-
eval 'exec ${PERL_HOME}/bin/perl ${PERL_ARGS} -x $0 ${1+"$@"}' 
  if 0;

# ------------------------------------------------------------------------
# Title:  ReqTrac join 2 CSV files
#
# File - templates/reqtrac.pl
# Version - 1.0
#
# Abstract:
# 
#    This tools merges a list or requirements with a list of tests
#    covering the requirements and generates a traceability matrix in
#    a comma separated values format.
#
#    The goal is to generate automatically the traceability matrix
#    to include in test plans.
#
#    To speed up development I am going to use
#    the file configuration format for requirments and for test list.
#
# Requirement formats:
# (start code)
# [Requirement_Section]
# REQ1 = "description of req1" 
# REQ2 = "description of req2" 
# REQ3 = "description of req3" 
# (end)
#
# Test list format:
# (start code)
# Test1 = REQ2, REQ3, REQ4
# Test2 = REQ7, REQ2
# (end)
#
# Output format:
# a comma separated values file
# (start code)
# Section_Name
# REQ1; "description of req1"; Test1, Test3
# REQ2; "description of req2"; Test4
# (end)
# ------------------------------------------------------------------------
package ReqTrac;

use strict;
use lib "$ENV{'PERL_TEST_TOOLS_PATH'}/lib";
use lib "$ENV{'PERL_TEST_TOOLS_PATH'}/lib/site_perl";
use TestTools::Script;
use TestTools::Parser::Aconfig;

use vars qw($VERSION @ISA @EXPORT);
use Exporter;

$VERSION = 1;
@ISA = qw(TestTools::Script);

# ########################################################################
# This hash table is used to declare and define options.
my %OptionSet = (
    requirements   =>  {
        type => "string",
        description => "Requirements file",
        default => ""
    },
    testlist   =>  {
        type => "string",
        description => "Tests list file",
        default => ""
    },
    result   =>  {
        type => "string",
        description => "Result file, (default = STDOUT)",
        default => ""
    },
);
    
# Below is the usage method thath you inherit. Delete it if it fits your
# needs or uncomment and adapt.
## ------------------------------------------------------------------------
## method: usage
##
##  Display how to call this script and exit.
## ------------------------------------------------------------------------
#sub usage {
#  my $Self = shift;
#
#  my $name = TestTools::Script::name();
#  my $parameters = "\[filenames\]*";
#
#  print "usage: perl $name \[options\] $parameters\n";
#  print STDERR TestTools::Conf::ScriptConfig::GetOnlineHelp() ; 
#  exit();
#}

# ------------------------------------------------------------------------
# routine: printHeader
#
#  print a CSV line for the colomn name
# ------------------------------------------------------------------------
sub printHeader {
    my ($Self, $fd) = @_;
    
    my @colName = ('Requirements', 'Description', 'Tests');
    
    print $fd join ("; ", @colName), "\n";
}

# ------------------------------------------------------------------------
# routine: printLine
#
#  print a CSV line for one configuration
#
# Parameter:
#    $fd   - file descriptor
#    $col1 - first colomne
#    $col2 - Second colomn or undef
#    $col3 - third colomn or undef
# ------------------------------------------------------------------------
sub printLine {
    my ($Self, $fd, $col1, $col2, $col3) = @_;

    print $fd $col1;
    
    if (!defined($col2)) {
        print $fd "\n";
        return;    
    }
        
    print $fd "; ";
    print $fd $col2;

    if (!defined($col3)) {
        print $fd "\n";
        return;    
    }   
        
    print $fd "; ";
    print $fd $col3;    
    print $fd "\n";
}


# ------------------------------------------------------------------------
# routine: addTestReq
#
#  Add a couple testname, requirement_id to the list
# ------------------------------------------------------------------------
sub addTestReq {
    my ($Self, $test, $req)  = @_;
    
    (exists($Self->{'reqs'}->{$req}->{'tests'})) or die "$req unknow requirement";
    
    if ($Self->{'reqs'}->{$req}->{'tests'} eq "") {
        $Self->{'reqs'}->{$req}->{'tests'} = $test;
    } else {
        $Self->{'reqs'}->{$req}->{'tests'} .= ", $test";        
    }
}

# ------------------------------------------------------------------------
# routine: process
#
#  Scrip main method.
# ------------------------------------------------------------------------
sub process {
    my ($Self, $fd, $reqs, $tests)  = @_;
    
    $Self->printHeader($fd);

    # Scan the requirements list an build a hash with the requirement
    # id as key.
    # for all sections
    foreach my $sect ( @{ $reqs->sections() } ) {
        # for all variables
        foreach my $var ( @{ $reqs->variables($sect) } ) {
            $Self->{'reqs'}->{$var}->{'tests'} = "";
        }        
    }    
    
    # scan the test list
    foreach my $tst (@{$tests->variables()}) {
        my $nb = $tests->numberOfValues(undef, $tst);
        if ($nb == 1) {
            $Self->addTestReq($tst, $tests->value(undef, $tst));
        } else {
            my @list = @{$tests->value(undef, $tst)};
            foreach my $elt (@list) {
                $Self->addTestReq($tst, $elt);
            }
        }
    }
    
    # Second parsing of the requirement list to print the result
    foreach my $sect ( @{ $reqs->sections() } ) {
        $Self->printLine($fd, "");
        $Self->printLine($fd, $sect);
        # for all variables
        foreach my $var ( @{ $reqs->variables($sect) } ) {
            $Self->printLine($fd, $var, $reqs->value($sect, $var), $Self->{'reqs'}->{$var}->{'tests'});
        }        
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

    my $result = $Self->GetOption('result');
    my $reqfilename = $Self->GetOption('requirements');
    my $testfilename = $Self->GetOption('testlist');
    my $fd = *STDOUT;
    
    if ($result ne "") {
        open( $fd, "> $result" ) || die("can't open $result: $!");
    }
    
    ($reqfilename ne "") or die "-requirements is a mandatory option";
    ($testfilename ne "") or die "-testfile is a mandatory option";
    
    my $reqs = new TestTools::Parser::Aconfig('filename' => $reqfilename);
    my $tests = new TestTools::Parser::Aconfig('filename' => $testfilename);

    # Treatments
    $Self->process($fd, $reqs, $tests);
    
    if ($result ne "") {
        close ($fd);
    }
}


# ------------------------------------------------------------------------
my $script = new ReqTrac();

$script->LoadOptions(%OptionSet);

my $Dir_Option = $script->GetOption('directory');
$script->info ( "Read option \'directory\' with GetOption service : $Dir_Option \n"); 

$script->run();
