# ------------------------------------------------------------------------
# Title:  Script Template
#
# Source - <file:../script.pl.html>
#
# Abstract:
#
#    This is a script template. It derives from the <Script> class, look
#    to the script class documentation for details.
#
#    This example parse directories and files to count the number of
#    occurence of a given pattern.
#
#    Place to customize are identified by a "To customize: comment"
#
# API Example:
#    Fill this section to demonstrate how to use the code.
#
# (Start code)
# (end)
#
# Usage:
# (Start code)
#   usage: perl ServerTemplate.pl [options] [filenames]*
#        -verbose         flag,     switch on verbose mode.
#        -help            flag,     display the online help.
#        -outputDirectory string,   directory for outputs
# (end)
#
# Output:
# (Start code)
# (end)
# ------------------------------------------------------------------------
# To customize: replace the package name
package ScriptTemplate;

use strict;
use 5.010;
use warnings;
use lib "$ENV{'FTF'}/lib";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Script;

$VERSION = 1;
@ISA     = qw(Script);

# To customize: add your own libraries
use Data::Dumper;
use ExecutionContext;
use ScriptConfiguration;

my $name = ExecutionContext::basename();

# ------------------------------------------------------------------------
# routine: process_file
#
#  Example of a file processing
#  To customize: replace or delete
# ------------------------------------------------------------------------
sub process_file {
    my ( $Self, $filename ) = @_;

    $Self->info( "processing file: " . $filename );
    my $pattern = $Self->{'pattern'};
    open( FD, "< $filename" ) or die("cannot open file $filename : $!");
    my $cnt = 0;
    my $lineNb = 0;
    while ( my $line = <FD> ) {
        $lineNb++;
        if ( $line =~ /$pattern/ ) {
            $cnt++;
            print "$filename:$lineNb $line";
        }
    }
    close FD;
    $Self->{'counter'} += $cnt;
    if ($cnt) {
        $Self->info("pattern $pattern found $cnt times in $filename");
    }
}

# ------------------------------------------------------------------------
# routine: run
#
#  Scrip main method. It is an example which recursively parse a
#  set of directories and apply a treatement to each file.
#  To customize:
# ------------------------------------------------------------------------
sub run {
    my $Self = shift;

    $Self->info("starting $name");

    # for all the files specified on CLI
    $Self->{'counter'} = 0;
    foreach my $arg (@ARGV) {
        while ( glob($arg) ) {
            if ( -d $_ ) {
                $Self->info( "processing directory: " . $_ );
            }
            if ( -f $_ ) {
                $Self->process_file($_);
            }
        }
    }
    say "Hello I am a script template, you can change me.";
    $Self->info("$name is completed");
}

# ------------------------------------------------------------------------
# On line help and options. 
# The full online help is the catenation of the header, 
# the parameters description and the footer. Parameters description
#  is automatically computed.

# To customize: you can remove help specification, remove the
# configuration file, remove additional parameters and even remove
# everything related to configuration.
my $help_header = "
Script template. 

usage: perl $name.pl [options]";

my $help_footer = "
Exemple:

    perl $name.pl -help
    perl $name.pl -pattern 'sub' script.pl
";

# If you specify a configuration file, it must exist.
my $configFile = ExecutionContext::configFile();

my $config = new ScriptConfiguration(
    'header'     => $help_header,
    'footer'     => $help_footer,
    'scheme'     => SCRIPT,
    'parameters' => {
        pattern => {
            type        => "string",
            description => "pattern to search",
            default     => "pattern"
          }          
    },    
#   'configFile' => $configFile
);

# create and run the script
# To customize: replace by your package name
my $script = new ScriptTemplate(
	loggerName => $name,
    pattern => $config->value('pattern'),
    verbose => $config->value('verbose')
);    
$script->run();
