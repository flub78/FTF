# ------------------------------------------------------------------------
# Title:  file truncate or dump
#
# File - scripts/truncate.pl
# Version - 1.0
#
# Abstract:
#
#    This script can be used to truncate binary files, to dump or delete
#    some parts or to insert something at an offset.
#
# Usage:
# (Start code)
#usage: perl truncate.pl [options] source [destination]
#        -verbose         flag,     switch on verbose mode.
#        -search          flag,     search for an hexadecimal pattern
#        -dump            flag,     dump contains between offset and offset + size
#        -insert          flag,     insert a pattern at offset
#        -outputDirectory string,   directory for outputs
#        -size            string,   size to truncate, display, etc.
#        -pattern         string,   hexadecimal string to insert, look for, etc
#        -delete          flag,     remove data between offset and offset + size
#        -help            flag,     display the online help.
#        -offset          string,   start offset
#
# (end)
# ------------------------------------------------------------------------
package Truncate;

use strict;
use lib "$ENV{'FTF'}/lib";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Script;
use File::Basename;

$VERSION = 1;
@ISA     = qw(Script);

use Data::Dumper;
use ExecutionContext;
use ScriptConfiguration;

# ------------------------------------------------------------------------
# On line help and options. 
my $help_header = '
usage: perl truncate.pl [options] filename';

my $help_footer = "";

# read CLI and configuration file
my $configFile = ExecutionContext::configFile();
my $config = new ScriptConfiguration(
    'header'     => $help_header,
    'footer'     => $help_footer,
    'scheme'     => SCRIPT,
    'parameters' => {
        dump => {
            type        => "flag",
            description => "dump contains between offset and offset + size",
            default     => 0
        },
        delete => {
                  type        => "flag",
                  description => "remove data between offset and offset + size",
                  default     => 0
        },
        search => {
                    type        => "flag",
                    description => "search for an hexadecimal pattern",
                    default     => 0
        },
        insert => {
                    type        => "flag",
                    description => "insert a pattern at offset",
                    default     => 0
        },
        pattern => {
                   type        => "string",
                   description => "hexadecimal string to insert, look for, etc",
                   default     => 0
        },
        offset => {
                    type        => "string",
                    description => "start offset",
                    default     => 0
        },
        size => {
                  type        => "string",
                  description => "size to truncate, display, etc.",
                  default     => 0
        }
    },
    #    'configFile' => $configFile
);


# ########################################################################

# ------------------------------------------------------------------------
# routine: toHexa
#
# Converts a binary buffer into an hexadecimal representation
#
# Parameters:
# buffer - String to convert
#
# Return: an hexadecimal string value
# ------------------------------------------------------------------------
sub toHexa {
    my ($buffer) = @_;

    my ($hex) = unpack( "H*", $buffer );
    return $hex;
}

# ------------------------------------------------------------------------
# routine: run
#
#  Scrip main method.
# ------------------------------------------------------------------------
sub run {
    my $Self = shift;

    my $source      = @ARGV[0];
    my $destination = @ARGV[1];
    my ( $buf, $fd1, $fd2 );

    if ( defined($destination) ) {
        print "destination defined $destination\n";
    } else {
        print "destination not defined\n";
    }

    my $offset = TestTools::Conf::ScriptConfig::GetOption('offset');
    my $size   = TestTools::Conf::ScriptConfig::GetOption('size');
    my $dump   = TestTools::Conf::ScriptConfig::GetOption('dump');

    unless ($size) {
        $size = ( -s $source ) - $offset;
    }

    my $bytesPerLine = 32;

    ( -e $source ) or die "$source no such file or directory";

    # open source
    open( $fd1, "<$source" ) or die("cannot open file $source!");
    binmode( $fd1, ":raw" );
    seek( $fd1, $offset, 0 );

    # open destination
    if ( defined($destination) ) {
        open( $fd2, "> $destination" ) or die("cannot open file $destination!");
        binmode( $fd2, ":raw" );
    }

    # file main loop
    while (
         read( $fd1, $buf, ( $size > $bytesPerLine ) ? $bytesPerLine : $size ) )
    {
        if ($dump) {
            printf "%08x", $offset;
            print " ", toHexa($buf), "\n";
        }

        if ( defined($destination) ) {
            print $fd2 $buf;
        }

        $offset += $bytesPerLine;
        $size -= ( $size > $bytesPerLine ) ? $bytesPerLine : $size;
    }

    # close files
    close($fd1);
    if ( defined($destination) ) {
        close($fd2);
    }
}

# ------------------------------------------------------------------------
my $script = new Truncate();
$script->run();
