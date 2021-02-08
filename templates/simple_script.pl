#!/usr/bin/perl

# ------------------------------------------------------------------------
# Title: New Script Template
#
# Source - <file:../simple_script.pl.html>
#
# Abstract:
#
#    See: usage for full description.
#
#    Compared to previous version this version uses a more modern Perl style
#    and some efforts have been made to make things simpler. Inheritance for
#    example is no more used at the script level.
#
# Usage:
# (Start code)
# usage: perl ./script2.pl [options]
#
#     Options:
#       -help            brief help message
#       -verbose         switch on verbose mode
#       -count           example of integer option
#       -pattern         pattern to search
#       
# Exemple:
#
#    perl ./script2.pl.pl -help
#    perl ./script2.pl.pl -pattern 'sub' script.pl
#    
# Features:
#
#    This script has been designed as an example that you can modify easily
#    to adapt it to your needs. The treatment given as example counts a pattern
#    in several files given as parameters.
#
#    - It is self documented using NaturalDocs (multi-languages, HTML, natural syntax)
#    - The command line is parsed using Getopt::Long;
#    - It supports a -help parameter
#    - It logs information using log4perl        

# (end)
# ------------------------------------------------------------------------
# Perl pragmas
use strict;
use warnings;
use 5.010;

# CPAN modules
use Getopt::Long;
use Log::Log4perl qw(:easy);

# Tool kit modules
use lib "$ENV{'FTF'}/lib";

# Script name
my $name = $0;
Log::Log4perl::init("$ENV{'FTF'}/conf/log4perl.conf");
my $log = Log::Log4perl->get_logger('script'); # log4perl.logger.script

# Default command line parameters
my $count = 0;
my $help;
my $verbose;
my $pattern = "";

# Command line arguments
my %arguments = (
	"count=i"   => \$count,    # numeric
	"help"      => \$help,      # flag
	"verbose"   => \$verbose,
	"pattern=s" => \$pattern
);

# ------------------------------------------------------------------------
# routine: usage
# ------------------------------------------------------------------------
sub usage () {
	say "
Script template. 

usage: perl $name [options]

     Options:
       -help            brief help message
       -verbose         switch on verbose mode
       -count           example of integer option
       -pattern         pattern to search
       
Exemple:

    perl $name.pl -help
    perl $name.pl -pattern 'sub' script.pl
    
Features:

    This script has been designed as an example that you can modify easily
    to adapt it to your needs. The treatment given as example counts a pattern
    in several files given as parameters.

    - It is self documented using NaturalDocs (multi-languages, HTML, natural syntax)
    - The command line is parsed using Getopt::Long;
    - It supports a -help parameter
    - It logs information using log4perl        
";
	exit();
}

# parse the CLI
my $result = GetOptions(%arguments);
if ($help) {
	usage();
}

# log invocation command
$log->info($0 . " " . join(" ",@ARGV)) if $verbose;

# ------------------------------------------------------------------------
# routine: process_file
#
#  Example of a file processing
# ------------------------------------------------------------------------
sub process_file {
    my ($filename ) = @_;

    $log->info( "processing file: " . $filename );
    open( FD, "< $filename" ) or die("cannot open file $filename : $!");
    my $cnt = 0;
    my $lineNb = 0;
    while ( my $line = <FD> ) {
        $lineNb++;
        if ( $line =~ /$pattern/ ) {
            $cnt++;
            $log->warn("$filename:$lineNb $line");
        }
    }
    close FD;
    $count += $cnt;
    if ($cnt) {
        $log->info("pattern $pattern found $cnt times in $filename");
    }
}

# processing command line arguments (not options)
foreach my $arg (@ARGV) {
    process_file ($arg);
}

# ------------------------------------------------------------------------
# routine: logFilename
#
# This routine is used in the log4perl configuration file
# It must stay in the global name space. If this version does not
# work for you just call it with the name you want.
#
# Return:
#     - The log file name.
# ------------------------------------------------------------------------
sub logFilename {
    return $0 . ".log";
}
