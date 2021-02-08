# ------------------------------------------------------------------------
# Title:  Smartcad reader
#
# Abstract:
#
#    Experimantation with a smartcard reader. 
# ------------------------------------------------------------------------
# To customize: replace the package name
package ScReader;

use strict;
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
use Chipcard::PCSC;

my $name = ExecutionContext::basename();


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

    print "Smartcar reader:\n";
    my $sc = new Chipcard::PCSC();
    die "Cannot create PCSC" unless($sc);
    
    my @rl = $sc->ListReaders();
    die "Cannot get list: $Chipcard::PCSC::errno" unless(defined($rl[0]));
    
    
    foreach my $reader (@rl) {
        print $reader . "\n";
    }
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
my $script = new ScReader(
	loggerName => $name,
    pattern => $config->value('pattern'),
    verbose => $config->value('verbose')
);    
$script->run();
