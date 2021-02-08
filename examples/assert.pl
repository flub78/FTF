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
use lib "$ENV{'FTF'}/lib";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Script;
use 5.010;
use warnings;

# Assertions are on.
use Carp::Assert;

$VERSION = 1;
@ISA     = qw(Script);

# To customize: add your own libraries
use Data::Dumper;
use ExecutionContext;
use ScriptConfiguration;

# ------------------------------------------------------------------------
# routine: process_file
#
#  Example of a file processing
#  To customize: replace or delete
# ------------------------------------------------------------------------
sub process_file {
    my ( $Self, $filename ) = @_;

    my $pattern = $Self->{'pattern'};
    open( FD, "< $filename" ) or die("cannot open file $filename : $!");
    while ( my $line = <FD> ) {
        if ( $line =~ /$pattern/ ) {
            $Self->{'counter'}++;
        }
    }
    close FD;
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

    my $name = ExecutionContext::basename();
    say "Hello I am a script with assertions";
    say "to disable";
    say "setenv NDEBUG 1";
    $Self->info("starting $name");
    assert ($name ne "");
    
    if ($Self->{'fail'}) {
        # wrong assertion 
        assert ($name eq "");
    }

    # for all the files specified on CLI
    $Self->{'counter'} = 0;
    foreach my $arg (@ARGV) {
        while ( glob($arg) ) {
            if ( -d $_ ) {
                $Self->info( "processing directory: " . $_ );
            }
            if ( -f $_ ) {
                $Self->info( "processing file: " . $_ );
                $Self->process_file($_);
            }
        }
    }
    say "Hello I am a script with assertions";
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
my $help_header = '
Script template. 

usage: perl ScriptTemplate.pl [options]';

my $help_footer = "
Exemple:

    perl ScriptTemplate.pl -help
    perl ScriptTemplate.pl -pattern 'o customize' my_script.pl
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
        },
        fail => {
            type        => "flag",
            description => "force some assertions to fail",
        }        
    },
);

# create and run the script
# To customize: replace by your package name
my $script = new ScriptTemplate( pattern => $config->value('pattern') );
$script->{'fail'} = $config->value('fail');
$script->run();
