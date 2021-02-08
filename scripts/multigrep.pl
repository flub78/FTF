#!/usr/bin/perl

# ------------------------------------------------------------------------
# Title: Multigrep
#
#
# Abstract:
#
#    Search a pattern in multiple files in multiple directories specified by a path.
#
# ------------------------------------------------------------------------
# Perl pragmas
use strict;
use warnings;
use 5.010;

# CPAN modules
use Getopt::Long;
use Log::Log4perl qw(:easy);
use Path::Class;
# IO::File is not used due to poor performance ...
# use IO::File;

# Tool kit modules
use lib "$ENV{'FTF'}/lib";

# Script name
my $name = $0;
Log::Log4perl::init("$ENV{'FTF'}/conf/log4perl.conf");
my $log = Log::Log4perl->get_logger('multigrep'); # log4perl.logger.script

# Default command line parameters
my $count = 0;
my $help;
my $verbose;
my $pattern = "unlikely_pattern";
my @default_dirs = @INC;
my @dirs = ();
my $extension = ".pm";

# Command line arguments
my %arguments = (
	"help"      => \$help,      # flag
	"verbose"   => \$verbose,
	"pattern=s" => \$pattern,
	"directories=s" => \@dirs,
	"extension=s" => \$extension
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
       -pattern         pattern to search
       -directories     directories to explore
       -extension       file extension, default=$extension
       
Exemple:

    perl $name.pl -help
    perl $name.pl -pattern 'sub' script.pl    
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

@dirs = @default_dirs unless (@dirs);

# ------------------------------------------------------------------------
# routine: process_file
#
#  File processing
# ------------------------------------------------------------------------
sub process_file {
    my ($filename ) = @_;

    return unless  ( $filename =~ /$extension/ );

    $log->debug( "processing: " . $filename );
       
    open( FD, "< $filename" ) or die("cannot open file $filename : $!");
    # my $fd = IO::File->new($filename, '<') or die("cannot open file $filename : $!");
    my $cnt = 0;
    my $lineNb = 0;
    while ( my $line = <FD> ) {
    # while (my $line = $fd->getline()) {
        $lineNb++;
        if ( $line =~ /$pattern/ ) {
            $cnt++;
            print("$filename:$lineNb $line");
        }
    }
    close FD;
    # $fd->close();
    $count += $cnt;
    if ($cnt) {
        $log->info("pattern $pattern found $cnt times in $filename");
    }
}

# ------------------------------------------------------------------------
# routine: process_dir
#
#  Directory processing
# ------------------------------------------------------------------------
sub process_dir {
    my ($directory ) = @_;

    $log->info( $directory );
    my $dir = dir($directory);
    foreach my $file ($dir->children()) {
        if (-d $file) {
            process_dir ($file);
        } else {
            process_file ($file);
        }
    }
}

# processing command line arguments (not options)
foreach my $path (@dirs) {
    process_dir ($path);
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
