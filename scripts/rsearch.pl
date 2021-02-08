#!/usr/bin/perl

# ------------------------------------------------------------------------
# Title:  rsearch recursive search
#
# File - scripts/rsearch.pl
# Version - 1.0
#
# Abstract:
#
#    Script to list, search patterns in or replace patterns in
#    a selection of files.
#
#    List, search or replace
#
# Usage:
# (Start code)
#perl rsearch.pl -help
#
#List, search or replace.
#
#    This script scan a list of files, directories and paths and processes them.
#    Path are directories names separated by ":". Files are directly processed, directories and paths
#    are recursively traversed and the contained files are processed.
#    Treatments are file name listing, pattern search or replacement (NYI).
#
#usage: perl ScriptTemplate.pl [options]
#        -verbose         flag    switch on verbose mode.
#        -filter          string  select only files matching this regular expression
#        -outputDirectory string  directory for outputs
#        -grep            string  look for this regular expression
#        -replace         string  replace the matching regular expression by this one
#        -skip            string  files filter, skip files matching this regular expression
#        -ignoreCase      flag    ignore cas in pattern matching
#        -help            flag    display the online help.
#        -wc              flag    like Uniw wc (word count), counts only the lines
#
#Exemple:
#
#    # select *.so files
#    perl rsearch.pl -filter '.*.so$'
#    # select *.hxx and *.cxx files
#    perl rsearch.pl -filter '.*.hxx$|.*.cxx^'
#    # look for a pattern in *.pm files
#    perl rsearch.pl -ignore -filter '.*.pm' -grep '^USE' $FTF/lib
# (end)
#
# Todo: replace mode
# ------------------------------------------------------------------------
package Rsearch;

use strict;
use lib "$ENV{'FTF'}/lib";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Script;
use File::Basename;

$VERSION = 1;
@ISA     = qw(Script);

# To customize: add your own libraries
use Data::Dumper;
use ExecutionContext;
use ScriptConfiguration;

# ------------------------------------------------------------------------
# On line help and options. 
my $help_header = '
List, search or replace.

    This script scan a list of files, directories and paths and processes them.
    Path are directories names separated by ":". Files are directly processed, directories and paths
    are recursively traversed and the contained files are processed.
    Treatments are file name listing, pattern search or replacement (NYI).

usage: perl ScriptTemplate.pl [options]';

my $help_footer = "
Exemple:

    # select *.so files
    rsearch -filter \'.*.so\$\ .' 
    # select *.hxx and *.cxx files
    rsearch -filter \'.*.hxx\$|.*.cxx^$\ .' 
    # look for a pattern in *.pm files
    rsearch -ignore -filter \'.*.pm\' -grep \'^USE\' \$FTF/lib .
    # count the number of Perl lines
    rsearch -filter '.*\.t\$|.*\.pm\$|.*\.pl\$' -wc \$FTF .
";

# read CLI and configuration file
my $configFile = ExecutionContext::configFile();
my $config = new ScriptConfiguration(
    'header'     => $help_header,
    'footer'     => $help_footer,
    'scheme'     => SCRIPT,
    'parameters' => {
        filter => {
            type        => "string",
            description => "select only files matching this regular expression",
            default     => ""
        },
        skip => {
            type => "string",
            description =>
              "files filter, skip files matching this regular expression",
            default => ""
        },

        grep => {
                  type        => "string",
                  description => "look for this regular expression",
                  default     => 0
        },

        replace => {
                     type => "string",
                     description =>
                       "replace the matching regular expression by this one",
                     default => 0
        },

        ignoreCase => {
                        type        => "flag",
                        description => "ignore cas in pattern matching",
                        default     => 0
        },
        wc => {
              type        => "flag",
              description => "like Uniw wc (word count), counts only the lines",
              default     => 0
          }

    },
    #    'configFile' => $configFile
);

# ########################################################################
# ------------------------------------------------------------------------
# routine: treat
#
#    File or directory treatment
# ------------------------------------------------------------------------
sub treat {
    my ( $Self, $file ) = @_;

    if ( -f $file ) {
        $Self->treatfile($file);
    }
    if ( -d $file ) {
        my $dirname = $file;
        if ( $Self->{'verbose'} ) {
            print( $file, ":\n" );
        }

        eval {
            opendir( my $fh, $dirname ) or die "can't opendir $dirname: $!";
            while ( defined( my $subfile = readdir($fh) ) ) {
                next if $subfile =~ /^\.\.?$/;    # skip . and ..
                      # do something with "$dirname/$subfile"
                my $name = $dirname . '/' . $subfile;
                $Self->treat($name);
            }
            closedir($fh);
        };
    }
}

# ------------------------------------------------------------------------
# routine: treatfile
#
#    Plain file treatment
# ------------------------------------------------------------------------
sub treatfile {
    my ( $Self, $file ) = @_;

    if ( $Self->{'filter'} ne "" ) {
        my $filter = $Self->{'filter'};
        return unless $file =~ /$filter/;
    }

    if ( $Self->{'skip'} ne "" ) {
        my $skip = $Self->{'skip'};
        return if $file =~ /$skip/;
    }

    if ( $Self->{'grep'} ) {
        $Self->grep( $file, $Self->{'grep'} );
    } elsif ( $Self->{'wc'} ) {

        # word count
        my $wc = $Self->wc($file);
        $Self->{'totalCount'} += $wc;
        $Self->{'totalFiles'} += 1;

        # my ( $base, $dir, $ext ) = fileparse( $file);
        my $dirname = File::Basename::dirname($file);
        $Self->{'wcByDir'}->{$dirname} += $wc;
        $Self->{'filesByDir'}->{$dirname} += 1;

        if ( $Self->{'verbose'} ) {
            print $file, ", wc = $wc\n";
        }
    } else {
        print( $file, " \n" );
    }
}

# ------------------------------------------------------------------------
# routine: grep
#
#    Look for a pattern in a file
# ------------------------------------------------------------------------
sub grep {
    my ( $Self, $file, $pattern ) = @_;

    my $lineNumber = 0;
    my $pattern    = $Self->{'grep'};
    my $ic         = $Self->{'ignore'};
    my $matchs     = 0;

    open( IN, "<", "$file" ) || die "cannot open $file: $!";
    my $line;
    while (<IN>) {
        $line = $_;
        $lineNumber++;
        if ($ic) {
            next unless $line =~ /$pattern/i;
        } else {
            next unless $line =~ /$pattern/;
        }
        $matchs++;
        print $file, ":", $lineNumber, " ", $line;
    }
    close(IN) || die "can't close  $file: $!";

    if ( $Self->{'verbose'} ) {
        if ( $matchs == 0 ) {
            print "$file = $pattern not found\n";
        }
    }
}

# ------------------------------------------------------------------------
# routine: wc
#
#    count the number of lines of a file
# ------------------------------------------------------------------------
sub wc {
    my ( $Self, $file ) = @_;

    my $lineNumber = 0;

    open( IN, "<", "$file" ) || die "cannot open $file: $!";
    my $line;
    while (<IN>) {
        $line = $_;
        $lineNumber++;
    }
    close(IN) || die "can't close  $file: $!";

    return $lineNumber;
}

# ------------------------------------------------------------------------
# routine: run
#
#  Scrip main method.
# ------------------------------------------------------------------------
sub run {
    my $Self = shift;

    my $name = ExecutionContext::basename();
    $Self->info("starting $name");

    # for all the files specified on CLI
    foreach my $arg (@ARGV) {
        my @list = split( /:/, $arg );
        foreach my $elt (@list) {
            while ( glob($elt) ) {
                $Self->treat($_);
            }
        }
    }

    if ( $Self->{'wc'} ) {
        print "\n";
        foreach my $dir ( sort( keys( %{ $Self->{'wcByDir'} } ) ) ) {
            print $dir;
            print ", files = ", $Self->{'filesByDir'}->{$dir};
            print ", lines = ", $Self->{'wcByDir'}->{$dir};
            print "\n";
        }
        print "Total number of lines = " . $Self->{'totalCount'} . "\n";
        print "Total number of files = " . $Self->{'totalFiles'} . "\n";
    }

    $Self->info("$name is completed");
}

# ------------------------------------------------------------------------
my $script = new Rsearch();

$script->{'filter'}  = $config->value('filter');
$script->{'verbose'} = $config->value('verbose');
$script->{'grep'}    = $config->value('grep');
$script->{'replace'} = $config->value('replace');
$script->{'skip'}    = $config->value('skip');
$script->{'ignore'}  = $config->value('ignoreCase');
$script->{'wc'}      = $config->value('wc');

$script->{'totalCount'} = 0;
$script->run();
