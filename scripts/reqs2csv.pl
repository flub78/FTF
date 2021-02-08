#!/bin/sh
#! -*- perl -*-
eval 'exec ${PERL_HOME}/bin/perl ${PERL_ARGS} -x $0 ${1+"$@"}'
  if 0;

# ------------------------------------------------------------------------
# Title:  Reqs2CSV requirements into CSV
#
# File - scripts/reqs2csv.pl
# Version - 1.0
#
# Abstract:
#
#    This tools read a set of configuration files and generate
#    a comma separated values file. Its goal is to generate Excel
#    sheet from a set of test description.
#
#    It also merges a list or requirements with a list of tests
#    covering the requirements and generates a traceability matrix in
#    a comma separated values format.
#
# Input:
#
#    - A requirements table ID, Description
#    - A file requirement table FileID, List of covered requirements
#    - a set of test description file.
#
#    Each test description contains
#    - a test id
#    - the test mode
#    - the list of covered assets
#    - the list of covered requirements.
#
# Output:
#
#    A comma separated values file, that can be imported into
#    a spreadsheet. containing:
#
#    - A test list with their attributs.
#    - A test list with the covered requirements for each test.
#    - Requirement list with the covering tests. This list is
#    organized into several sections.
#
#
#    To speed up development I am going to use
#    the file configuration format for requirments and for test list.
#    Future versions should probably get their data from a real database
#
# Requirement formats:
# (start code)
# [Requirement_Section]
# REQ1 = "description of req1"
# REQ2 = "description of req2"
# REQ3 = "description of req3"
# (end)
#
# Test description format:
# (start code)
# [Scenario]
#    name = SCENARIOX
#    Mode = polling
#    Algo = AES128/CBC
# [Assets]
#    file1  = xxxx
#    error1 = yyyy
#    file2  = xxxx
# [Requirements]
#    SCENARIOX = REQ1, REQ122, REQ43
#
# (end)
#
# Output format:
# a comma separated values file
# (start code)
# Section_Name
# REQ1; "description of req1"; Test1, Test3
# REQ2; "description of req2"; Test4
# (end)
#
#   Example:
#       > perl reqs2csv.pl -v
#
# TODO Only print the basename in the first table
# ------------------------------------------------------------------------
package Reqs2CSV;

use strict;
use lib "$ENV{'PERL_TEST_TOOLS_PATH'}/lib";
use lib "$ENV{'PERL_TEST_TOOLS_PATH'}/lib/site_perl";
use TestTools::Script;
use TestTools::Parser::Aconfig;
use TestTools::Utilities::Lists;

use vars qw($VERSION @ISA @EXPORT);
use Exporter;

$VERSION = 1;
@ISA     = qw(TestTools::Script);

# ########################################################################
# This hash table is used to declare and define options.
my %OptionSet = (
    result => {
        type        => "string",
        description => "directories to parse",
        default     => ""
    },
    requirements => {
        type        => "string",
        description => "Requirements list",
        default     => ""
    },
    assetlist => {
        type        => "string",
        description => "List of assets with requirements",
        default     => ""
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
# routine: printLine
#
#  print a CSV line for one configuration
#
# Parameter:
#    $fd   - file descriptor
#    @_    - list of colomns
# ------------------------------------------------------------------------
sub printLine {
    my $Self = shift;
    my $fd   = shift;

    print $fd join( ";", @_ ), "\n";
}

# ------------------------------------------------------------------------
# routine: printListLine
#
#  print a CSV line for one configuration
# ------------------------------------------------------------------------
sub printListLine {
    my ( $Self, $fd, $cfg ) = @_;

    print $fd $cfg->value( 'Scenario', 'Identification' );
    print $fd "; ";
    print $fd $cfg->value( 'Scenario', 'SubmissionMode' );
    print $fd "; ";
    print $fd $cfg->value( 'Scenario', 'keepProtectedCCF' );
    print $fd "; ";
    print $fd $cfg->value( 'Scenario', 'exportedScwClientKey' );
    print $fd "; ";
    print $fd $cfg->value( 'Scenario', 'encryptionAlgorithm' );
    print $fd "; ";
    print $fd $cfg->value( 'Scenario', 'encryptionLevel' );
    print $fd "; ";
    print $fd $cfg->value( 'Scenario', 'cryptoPeriod' );
    print $fd "; ";
    print $fd $cfg->value( 'Scenario', 'MemoryCheck' );
    print $fd "; ";
    print $fd $cfg->value( 'Scenario', 'Iterations' );
    print $fd "; ";
    print $fd $cfg->value( 'Scenario', 'PerformanceCheck' );
    print $fd "; ";
    print $fd $cfg->value( 'Scenario', 'scwClientKey' );
    print $fd "; ";
    print $fd $cfg->value( 'Assets', 'file0' );
    print $fd "; ";
    print $fd $cfg->value( 'Assets', 'error0' );
    print $fd "\n";

    my @list = @{ $cfg->variables('Assets') };
    my $nb   = scalar(@list);
    $nb = ( $nb / 2 ) - 1;
    for ( my $i = 1 ; $i <= $nb ; $i++ ) {
        my $file  = "file" . $i;
        my $error = "error" . $i;
        print $fd "; " x 11;
        print $fd $cfg->value( 'Assets', $file );
        print $fd "; ";
        print $fd $cfg->value( 'Assets', $error );
        print $fd "\n";
    }
}

# ------------------------------------------------------------------------
# routine: readAssets
#
#  Read assets table and store them into the object
# ------------------------------------------------------------------------
sub readAssets {
    my ( $Self, $assets ) = @_;

    my @list = @{ $assets->variables() };

    foreach my $file (@list) {
        my $nb = $assets->numberOfValues( undef, $file );
        if ( $nb == 1 ) {
            my $req = $assets->value( undef, $file );
            $Self->{'filereq'}->{$file} = [$req];

        }
        elsif ( $nb > 1 ) {
            $Self->{'filereq'}->{$file} = $assets->value( undef, $file );
        }
    }
}

# ------------------------------------------------------------------------
# routine: testsList
#
#  Generate the test list
# ------------------------------------------------------------------------
sub testsList {
    my ( $Self, $fd ) = @_;

    my @colName = (
        'Name',      'Mode',  'Keep ProtCCF',  'Export SCWCK',
        'Algo',      'Level', 'CryptoPeriode', 'Memory',
        'Iteration', 'Perf',  'SCWClientKey',  'Files',
        'Errors'
    );

    # print header
    $Self->printLine( $fd, @colName );

    # for all the files specified on CLI
    foreach my $arg (@ARGV) {
        while ( glob($arg) ) {
            my $filename = $_;
            my $cfg = new TestTools::Parser::Aconfig( 'filename' => $filename );

            $Self->printListLine( $fd, $cfg );
        }
    }
}

# ------------------------------------------------------------------------
# routine: addTestToReq
#
#  Attach a test to a requirement
# ------------------------------------------------------------------------
sub addTestToReq {
    my ( $Self, $req, $test) = @_;

    # print "addTestToReq ($req, $test)\n";

    if (!exists($Self->{'reqs'}->{$req}) ) {
        $Self->{'reqs'}->{$req} = [$test];
    } else {
        unless (TestTools::Utilities::Lists::found ($test, $Self->{'reqs'}->{$req})) {;
            push (@{$Self->{'reqs'}->{$req}}, $test);
        }
    }
    
    if (!exists($Self->{'tests'}->{$test}) ) {
        $Self->{'tests'}->{$test} = [$req];
    }
    else {
        unless (TestTools::Utilities::Lists::found ($req, $Self->{'tests'}->{$test})) {
            push (@{$Self->{'tests'}->{$test}}, $req);
        }
    }
        
}


# ------------------------------------------------------------------------
# routine: extractTestReq
#
#  Extract requirements from a test description and
#  print a line
# ------------------------------------------------------------------------
sub extractTestReq {
    my ( $Self, $fd, $tst ) = @_;

    my @reqlist;

    # Extract the requirements from the asset list
    my $test_id = $tst->value( 'Scenario', 'Identification' );
    my @list = @{ $tst->variables('Assets') };
    my $nb   = scalar(@list);
    $nb = ( $nb / 2 ) - 1;
    for ( my $i = 1 ; $i <= $nb ; $i++ ) {
        my $file = "file" . $i;
        my $filename = $tst->value( 'Assets', $file );

        if ( exists( $Self->{'filereq'}->{$filename} ) ) {
            foreach my $req ( @{ $Self->{'filereq'}->{$filename} } ) {
                push( @reqlist, $req );
                $Self->addTestToReq( $req, $test_id );
            }
        }
    }

    # Extract the requirements from the test description
    my $reqsect = 'Requirements';
    if ( defined( $tst->variables($reqsect) ) ) {

        my @list = @{ $tst->variables($reqsect) };
        foreach my $var (@list) {

            my $nb = $tst->numberOfValues( $reqsect, $var );
            if ( $nb == 1 ) {
                $Self->addTestToReq( $tst->value( $reqsect, $var ), $var );
                push( @reqlist, $tst->value( $reqsect, $var ) );
            }
            else {
                my @list = @{ $tst->value( $reqsect, $var ) };
                foreach my $elt (@list) {
                    $Self->addTestToReq( $elt, $var );
                    push( @reqlist, $elt );
                }
            }
        }

    }

    # Print a line in the test / requirements table
    my $test_id = $tst->value( 'Scenario', 'Identification' );
    my $req_list = "";
    if (exists($Self->{'tests'}->{$test_id})) {
        $req_list = join( ", ", @{$Self->{'tests'}->{$test_id}} );
    } else {}
    print $fd $test_id, "; ", $req_list, "\n";
}

# ------------------------------------------------------------------------
# routine: testTracMatrix
#
# Generates the traceability matrix for tests
# ------------------------------------------------------------------------
sub testTracMatrix {
    my ( $Self, $fd, $reqs, $tests ) = @_;

    print $fd "\n";

    # scan the test list
    $Self->printLine( $fd, "" );
    $Self->printLine( $fd, "List or requirements per test" );
    $Self->printLine( $fd, "Test", "Requirements" );

    # for all the files specified on CLI
    foreach my $arg (@ARGV) {
        while ( glob($arg) ) {
            my $filename = $_;
            my $cfg = new TestTools::Parser::Aconfig( 'filename' => $filename );

            $Self->extractTestReq( $fd, $cfg );
        }
    }
}

# ------------------------------------------------------------------------
# routine: reqTracMatrix
#
# Generates the traceability matrix for reqs
# ------------------------------------------------------------------------
sub reqTracMatrix {
    my ( $Self, $fd, $reqs, $tests ) = @_;

    # Second parsing of the requirement list to print the result
    foreach my $sect ( @{ $reqs->sections() } ) {
        $Self->printLine( $fd, "" );
        $Self->printLine( $fd, "Section:", $sect );

        # print header
        $Self->printLine( $fd, ( 'Requirements', 'Description', 'Tests' ) );

        # for all variables
        foreach my $var ( @{ $reqs->variables($sect) } ) {
            my $value = $reqs->value( $sect, $var );

            # Workaround for a small bug in aconfig. Commas inside
            # quotes string should not be interpreted as list element
            # separator. To fix later in aconfig.pm
            my $description;
            if ( ref($value) eq 'ARRAY' ) {
                $description = join( ", ", @{$value} );
            }
            else {
                $description = $value;
            }

            my $tests = "no tests for this requirement";
            if ( exists( $Self->{'reqs'}->{$var} ) ) {
                $tests = join (", ", @{$Self->{'reqs'}->{$var}});
            }
            $Self->printLine( $fd, $var, $description, $tests );
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

    # print "\n\n############################################################\n";
    my $name = TestTools::Script::basename();

    my $result      = $Self->GetOption('result');
    my $reqfilename = $Self->GetOption('requirements');
    my $assetlist   = $Self->GetOption('assetlist');

    my $fd = *STDOUT;
    my $filename;

    if ( $result ne "" ) {
        $filename = "tests_" . $result;
        open( $fd, "> $filename" ) || die("can't open $filename: $!");
    }

    $Self->testsList($fd);

    if ( $assetlist ne "" ) {
        my $assets = new TestTools::Parser::Aconfig( 'filename' => $assetlist );
        $Self->readAssets($assets);
    }

    if ( $reqfilename ne "" ) {
        my $reqs = new TestTools::Parser::Aconfig( 'filename' => $reqfilename );

        if ( $result ne "" ) {
            $filename = "testTrac_" . $result;
            open( $fd, "> $filename" ) || die("can't open $filename: $!");
        }

        $Self->testTracMatrix( $fd, $reqs );
        if ( $result ne "" ) {
            $filename = "reqTrac_" . $result;
            open( $fd, "> $filename" ) || die("can't open $filename: $!");
        }
        $Self->reqTracMatrix( $fd, $reqs );
    }

    if ( $result ne "" ) {
        close($fd);
    }
}

# ------------------------------------------------------------------------
my $script = new Reqs2CSV();

$script->LoadOptions(%OptionSet);

my $Dir_Option = $script->GetOption('directory');
$script->info(
    "Read option \'directory\' with GetOption service : $Dir_Option \n");

$script->run();
