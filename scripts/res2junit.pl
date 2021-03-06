# ------------------------------------------------------------------------
# Title:  Res2junit
#
# Abstract:
#
#    Transfom a set of results files generated by FTF test scripts
#    into XML files compatible with Junit. The goal is to integrate
#    perl tests with tools which are compatible with Junit.
# ------------------------------------------------------------------------
package Res2Junit;

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
use Reporters::TestResultParser;

my $name = ExecutionContext::basename();

# ------------------------------------------------------------------------
# routine: treatfile
#
#  Example of a file processing
#  To customize: replace or delete
# ------------------------------------------------------------------------
sub treatfile {
    my ( $Self, $filename ) = @_;

    if ( $Self->{'filter'} ne "" ) {
        my $filter = $Self->{'filter'};
        return unless $filename =~ /$filter/;
    }

    if ( $Self->{'skip'} ne "" ) {
        my $skip = $Self->{'skip'};
        return if $filename =~ /$skip/;
    }

    $Self->info( "processing file: " . $filename );
    
    my $tr = new Reporters::TestResultParser( filename => $filename );
    print Dumper($tr);
    return;
    
    open( FD, "< $filename" ) or die("cannot open file $filename : $!");
    my $cnt = 0;
    my $lineNb = 0;
    while ( my $line = <FD> ) {
        $lineNb++;
        print "$filename:$lineNb $line";
        
    }
    close FD;
}

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
        	$Self->treat($_);
        }
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
        report => {
            type        => "string",
            description => "name of the generated report",
            default     => ""
        },        
    },    
);

# create and run the script
# To customize: replace by your package name
my $script = new Res2Junit(loggerName => $name);
$script->{'filter'}  = $config->value('filter');
$script->{'verbose'} = $config->value('verbose');
$script->{'skip'}    = $config->value('skip');
    
$script->run();
