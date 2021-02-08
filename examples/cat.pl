#!/usr/bin/perl

# ------------------------------------------------------------------------
# Title: cat
#
# Abstract:
#
#    print files on the standard output
#
#    The script demonstrates the usage of the FTF library
#
# Usage:
# (Start code)
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
use FileContent;

# Script name
my $name = $0;
Log::Log4perl::init("$ENV{'FTF'}/conf/log4perl.conf");
my $log = Log::Log4perl->get_logger('script'); # log4perl.logger.script

# Default command line parameters
my $help;
my $verbose;

# Command line arguments
my %arguments = (
	"help"      => \$help,      # flag
	"verbose"   => \$verbose
);

# ------------------------------------------------------------------------
# routine: usage
# ------------------------------------------------------------------------
sub usage () {
	say "
Script template. 

usage: perl $name [options] filenames*

     Options:
       -help            brief help message
       -verbose         switch on verbose mode
       
Exemple:

    perl $name -help
    perl $name -pattern 'sub' script.pl
";
	exit();
}

# log invocation command
$log->info($0 . " " . join(" ",@ARGV));

# parse the CLI
my $result = GetOptions(%arguments);
if ($help) {
	usage();
}

# processing command line arguments (not options)
foreach my $arg (@ARGV) {
    $log->info( "processing file: " . $arg );
    say readFile ($arg);
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
