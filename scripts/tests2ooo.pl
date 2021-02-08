#!/bin/sh
#! -*- perl -*-
eval 'exec ${PERL_HOME}/bin/perl ${PERL_ARGS} -x $0 ${1+"$@"}'
  if 0;

# ------------------------------------------------------------------------
# Title:  tests2ooo configuration file to Open Office
#
# File - scripts/tests2ooo.pl
# Version - 1.0
#
# Abstract:
#
#    This tools read a set of configuration files and generate
#    an OpenOffice document. 
#
#    It also merges a list or requirements with a list of tests
#    covering the requirements and generates the traceability matrices.
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
#    An Open Office document.
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
# (end)
#
# ------------------------------------------------------------------------
package Tests2OOO;

use strict;
use lib "$ENV{'PERL_TEST_TOOLS_PATH'}/lib";
use lib "$ENV{'PERL_TEST_TOOLS_PATH'}/lib/site_perl";
use TestTools::Script;
use TestTools::Parser::Aconfig;
use TestTools::Utilities::Sets;
use TestTools::Doc::DocGen;

use Data::Dumper;

use vars qw($VERSION @ISA @EXPORT);
use Exporter;

$VERSION = 1;
@ISA     = qw(TestTools::Script);

# ########################################################################
# This hash table is used to declare and define options.
my %OptionSet = (
    template => {
        type        => "string",
        description => "template document to complete",
        default     => "nagra.ott"
    },
    requirements => {
        type        => "string",
        description => "Requirements list",
        default     => ""
    },
    result => {
        type        => "string",
        description => "result document",
        default     => "out.oot"
    },    
    assetlist => {
        type        => "string",
        description => "List of assets with requirements",
        default     => ""
    }
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
# routine: readAssets
#
#  Read assets table and store them into the object
# ------------------------------------------------------------------------
sub readAssets {
    my ( $Self, $assets ) = @_;

    my @list = @{ $assets->variables() };

    foreach my $file (@list) {
        # print "file = $file\n";
        my $nb = $assets->numberOfValues( undef, $file );
        # print "nb = $nb\n";
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
    my ( $Self, $doc ) = @_;

    $doc->appendHeading(1, "Tests List");
    $doc->appendParagraph(text => "");

    my $table = $doc->appendTable( "TestList", scalar(@ARGV) + 1, 2 );
    $doc->cellValue( $table, 0, 0, 'Test Identification' );
    $doc->cellValue( $table, 0, 1, 'Short Description' );

    # To have the first list repeated on top of each page
    $doc->doc()->copyRowToHeader ($table, 0);
    $doc->doc()->deleteRow ($table, 0);

    my $cnt = 0;            
    # for all the files specified on CLI
    foreach my $arg (@ARGV) {
        while ( glob($arg) ) {
            my $filename = $_;
            my $cfg = new TestTools::Parser::Aconfig( 'filename' => $filename );

            my $testId = $cfg->value( 'Scenario', 'Identification' );
            my $description = $cfg->value( 'Scenario', 'ShortDescription' );
            
            $doc->cellValue( $table, $cnt, 0, $testId );
            $doc->cellValue( $table, $cnt, 1, $description );
            $cnt++;
        }
    }
}

# ------------------------------------------------------------------------
# routine: testsDescription
#
#  Generate the tests Detailed Description
# ------------------------------------------------------------------------
sub testsDescription {
    my ( $Self, $doc ) = @_;

    my @colName = (
        'Name',      'Mode',  'Keep ProtCCF',  'Export SCWCK',
        'Algo',      'Level', 'CryptoPeriode', 'Memory',
        'Iteration', 'Perf',  'SCWClientKey',  'Files',
        'Errors'
    );

    $doc->appendHeading(1, "Tests Detailed Description");

    # for all the files specified on CLI
    foreach my $arg (@ARGV) {
        while ( glob($arg) ) {
            my $filename = $_;
            my $cfg = new TestTools::Parser::Aconfig( 'filename' => $filename );

            my $testId = $cfg->value( 'Scenario', 'Identification' );
            $doc->appendHeading(2, "Test " . $testId);
            $doc->appendParagraph(text => "");
            
            foreach my $att (qw (ShortDescription SubmissionMode keepProtectedCCF exportedScwClientKey encryptionAlgorithm
            encryptionLevel cryptoPeriod MemoryCheck Iterations PerformanceCheck scwClientKey)) {
                my $value = $cfg->value( 'Scenario', $att );
                $doc->appendParagraph(text => "$att = $value");
            }
            
            $doc->appendParagraph(text => "");
            my $desc = $cfg->header();
            # print "description = $desc\n";
            my @descr = split ("\n# ", $desc);
            foreach my $line (@descr) {
                $doc->appendParagraph(text => $line);
            }
        }
    }
}

# ------------------------------------------------------------------------
# routine: addTestToReq
#
#  Attach a test to a requirement
# ------------------------------------------------------------------------
sub addTestToReq {
    my ( $Self, $req, $test ) = @_;

    # print "addTestToReq ($req, $test)\n";

    if ( !exists( $Self->{'reqs'}->{$req} ) ) {
        $Self->{'reqs'}->{$req} = [$test];
    }
    else {
        unless (
            TestTools::Utilities::Sets::found(
                $test, $Self->{'reqs'}->{$req}
            )
          )
        {
            ;
            push( @{ $Self->{'reqs'}->{$req} }, $test );
        }
    }

    if ( !exists( $Self->{'tests'}->{$test} ) ) {
        $Self->{'tests'}->{$test} = [$req];
    }
    else {
        unless (
            TestTools::Utilities::Sets::found(
                $req, $Self->{'tests'}->{$test}
            )
          )
        {
            push( @{ $Self->{'tests'}->{$test} }, $req );
        }
    }

}

# ------------------------------------------------------------------------
# routine: extractTestReq
#
#  Extract requirements from a test description and
#  fill a line
# ------------------------------------------------------------------------
sub extractTestReq {
    my ( $Self, $doc, $tst, $table, $line ) = @_;

    # Extract the requirements from the asset list
    my $test_id = $tst->value( 'Scenario', 'Identification' );

    my @list = @{ $tst->variables('Assets') };

    foreach my $file (@list) {
        if ( $file =~ /^error(\d)*$/ ) {
            # filter errors
            next;
        }

        my $filename = $tst->value( 'Assets', $file );

        if ( exists( $Self->{'filereq'}->{$filename} ) ) {
            # print "there are associated reqs\n";
            foreach my $req ( @{ $Self->{'filereq'}->{$filename} } ) {
                # print "################### $req $test_id\n";
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
            }
            else {
                my @list = @{ $tst->value( $reqsect, $var ) };
                foreach my $elt (@list) {
                    $Self->addTestToReq( $elt, $var );
                }
            }
        }
    }

    # Print a line in the test / requirements table
    my $test_id = $tst->value( 'Scenario', 'Identification' );
    my $req_list = "";
    if ( exists( $Self->{'tests'}->{$test_id} ) ) {
        $req_list = join( ", ", @{ $Self->{'tests'}->{$test_id} } );
    }
    else {
    }
    $doc->cellValue( $table, $line, 0, $test_id );
    $doc->cellValue( $table, $line, 1, $req_list );
}

# ------------------------------------------------------------------------
# routine: testTracMatrix
#
# Generates the traceability matrix for tests
# ------------------------------------------------------------------------
sub testTracMatrix {
    my ( $Self, $doc, $reqs ) = @_;

    $doc->appendHeading(1, "Requirements Traceability Matrix");
    
    $doc->appendParagraph(text => "This section presents the list of requirements covevered by each test.");
    $doc->appendParagraph(text => "");

    my $table = $doc->appendTable( 'ReqsTrac', scalar(@ARGV) + 1, 2 , 'table-style' => 'Nagra1');
    $doc->cellValue( $table, 0, 0, 'Tests' );
    $doc->cellValue( $table, 0, 1, 'Requirements' );
    
    # for all the files specified on CLI
    my $cnt = 1;
    foreach my $arg (@ARGV) {
        while ( glob($arg) ) {
            my $filename = $_;
            my $cfg = new TestTools::Parser::Aconfig( 'filename' => $filename );

            $Self->extractTestReq( $doc, $cfg, $table, $cnt++ );
        }
    }
}

# ------------------------------------------------------------------------
# routine: reqTracMatrix
#
# Generates the traceability matrix for reqs
# ------------------------------------------------------------------------
sub reqTracMatrix {
    my ( $Self, $doc, $reqs, $tests ) = @_;

    $doc->appendHeading(1, "Tests Traceability Matrix");
    $doc->appendParagraph(text => "This section presents the list of requirements with the their list of related test.");
    $doc->appendParagraph(text => "");
    
    # Second parsing of the requirement list to print the result
    foreach my $sect ( @{ $reqs->sections() } ) {

        next if ( $sect =~ /_anonymous/ );
        
        $doc->appendHeading(2, "Section: " . $sect);
        $doc->appendParagraph(text => "");

        my @sections = @{ $reqs->variables($sect) };
        
        # print header
        my $table = $doc->appendTable( $sect, scalar(@sections) + 1, 3 );
        $doc->cellValue( $table, 0, 0, 'Requirements' );
        $doc->cellValue( $table, 0, 1, 'Description' );
        $doc->cellValue( $table, 0, 2, 'Tests' );

        # To have the first list repeated on top of each page
        $doc->doc()->copyRowToHeader ($table, 0);
        $doc->doc()->deleteRow ($table, 0);

        my $cnt = 0;
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
                $tests = join( ", ", @{ $Self->{'reqs'}->{$var} } );
            }
            $doc->cellValue( $table, $cnt, 0, $var );
            $doc->cellValue( $table, $cnt, 1, $description );
            $doc->cellValue( $table, $cnt, 2, $tests );
            $cnt++;
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

    my $reqfilename = $Self->GetOption('requirements');
    my $assetlist   = $Self->GetOption('assetlist');
    my $result      = $Self->GetOption('result');
    my $template    = $Self->GetOption('template');

    die "Missing output filename\n"   unless $result;

    # Create an OpenOffice document
    my $doc = new TestTools::Doc::DocGen(
        'template' => $template,
    );
    $Self->{'doc'} = $doc;
    
    # Set some meta data
    $doc->subject('Tests Description Plan');
    $doc->title('CPE 2.3STD5 Test Plan');
    $doc->description(
        'This document contains the detailed description of the tests of the Pre-Encryption Station Software Component.'
    );
    $doc->keywords( 'Perl', 'Documentation', 'Tests', 'Validation' );
    
    my $filename;

    $Self->testsList($doc);
    $Self->testsDescription($doc);

    if ( $assetlist ne "" ) {
        my $assets = new TestTools::Parser::Aconfig( 'filename' => $assetlist );
        $Self->readAssets($assets);
    }

    if ( $reqfilename ne "" ) {
        my $reqs = new TestTools::Parser::Aconfig( 'filename' => $reqfilename );

        $Self->testTracMatrix( $doc, $reqs );
        $Self->reqTracMatrix( $doc, $reqs );
    }

    # Close and save
    $doc->appendParagraph( text => "" );
    $doc->appendParagraph( style => 'Centre', text => "- End of document -" );
    
    $doc->save($result);
    print "$result generated\n";
    
#    my @styles = $doc->doc()->getAutoStyleList ();
#    print "Styles = \n";
#    foreach my $style (@styles) {
#        print Dumper ($style), "\n";
#    }
                
}

# ------------------------------------------------------------------------
my $script = new Tests2OOO();

$script->LoadOptions(%OptionSet);

$script->run();
