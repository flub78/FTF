# ------------------------------------------------------------------------
# Title:  Module ExecutionContext
#
# File - ExecutionContext.pm
# Version - 1.0
#
# Abstract:
#
#    Execution context management. This module provides information and services
#    on the script execution context. It also manages global data associated with the
#    script execution like;
#       - a default configuration file name. By default it is the script basename plus 
#       a .ini extension located in the same directory than the script. 
#       - a default log file name, by defaultthe script basename with a .log
#       extension in the current directory.
#
#    If the defaults does not suit your needs, you can replace set the
#    configuration file or output file with the same routines.
#   
#    path() = directory() . basename() . extension();
#
# ------------------------------------------------------------------------
package ExecutionContext;

use strict;
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use English;

use File::Basename qw(fileparse);
use File::Spec;
use Data::Dumper;
use Getopt::Long;
use Cwd;
use ClassWithLogger;

@ISA     = qw(Exporter);
@EXPORT = qw (path directory basename extension configFile logFilename);

$VERSION = 1;

# ------------------------------------------------------------------------
# routine: path
#
# Returns the absolute full path of the script.
# ------------------------------------------------------------------------
sub path {
    
    if ($OSNAME eq "MSWin32") {
        return $0;
    }

    # $0 contains the script name
    if ( $0 =~ /^\s*\// ) {
        # absolute path
        return $0;
    }
    else {
        # it is a relative path, compute the absolute path
        # my $dir = `pwd`;
        my $dir = getcwd();
        chomp($dir);
        return $dir . '/' . $0;
    }
}

# ------------------------------------------------------------------------
# routine: directory
#
# Returns the script directory. It is not the working directory.
# Can be use to access file from the script with a relative addressing.
# ------------------------------------------------------------------------
sub directory {
    my ($path) = @_;
    
    unless (defined($path)) {
        $path = path();
    }
    my ( $base, $dir, $ext ) = fileparse( $path, extension() );
    if ($dir =~ /\/cygdrive\/.?(.*)/) {
        $dir = $1;
    }   
    return $dir;
}

# ------------------------------------------------------------------------
# routine: extension
#
# Returns the script extension.
# ------------------------------------------------------------------------
sub extension {
    my @list = split( /\./, path() );

    my $len = scalar(@list);
    if ( $len <= 1 ) {
        return "";
    }
    else {
        return '.' . $list[ $len - 1 ];
    }
}

# ------------------------------------------------------------------------
# routine: basename
#
# Parameters:
# @suffixes - list of extension to remove.
#
# Returns the base file name of the script path.
# ------------------------------------------------------------------------
sub basename {
    if (@_) {
        my ( $base, $dir, $ext ) = fileparse( path(), @_ );
        return $base;
    }
    else {
        my ( $base, $dir, $ext ) = fileparse( path(), extension());
        return $base;    
    }
}

# ------------------------------------------------------------------------
# routine: configFile
#
#   Set or get the name of the configuration file. By default
#   configuration fiels are basename.ini in the current directory
#
# return:
# - The configuration file name.
# ------------------------------------------------------------------------
my $configFile;
sub configFile {

    my $value = shift;
    
    if ( defined($value) ) {
        $configFile = $value;
    }
    unless ( defined($configFile) ) {
        $configFile = directory() . basename() . '.ini';
    }
    return $configFile;
}

# ------------------------------------------------------------------------
# method: context
#
#   Print information about the script execution context. It has been
#   choosen to start each line by a pound sign to make the display
#   compatible with Test::More output.
# ------------------------------------------------------------------------
sub context {
    my $Self = shift;

    my $pwd = `pwd`;
    chomp($pwd);
    my $res = "";
    $res .= "Script = " . $0 . "\n";
    $res .= "Script path = " . path() . "\n";
    $res .= "Script basename = " . basename() . "\n";
    $res .= "Script directory = " . directory() . "\n";
    $res .= "Working directory = " . $pwd . "\n";
    $res .= "Configuration file name = " . configFile() . "\n";
    $res .= "Log file = " . main::logFilename() . "\n";
    $res .= "Log configuration file = " . ClassWithLogger::logConfigFile() . "\n";
    my $date = `date`;
    chomp($date);
    $res .= "Date = " . $date . "\n";
    $res .= "User = " . $ENV{'USER'} . "\n";
    $res .= "OS = " . $OSNAME . "\n";
    $res .= "Command line Arguments = " . join( " ", @ARGV ) . "\n";
    return $res;
}

########################################################################
package main;

# ------------------------------------------------------------------------
# routine: logFilename
#
# This routine is used in the log4perl configuration file
# It must stay in the global name space. If this version does not
# work for you just call it with the name you want.
#
# When the FTF_LOG environment variable is not defined, the default
# is the script basename with '.log' extension in the current
# directory. When the environment variable is set, it is used to 
# put the file.
#
# Return:
#     - The log file name.
# ------------------------------------------------------------------------
my $logFilename;
sub logFilename {

    my ($value) = @_;
    if ( defined($value) ) {
        $logFilename = $value;
    }

    unless (defined($logFilename)) {
        if (exists($ENV{'FTF_LOG'})) {
            $logFilename = $ENV{'FTF_LOG'} . 
                '/' . ExecutionContext::basename() . '.log';
        } else {
            # log file in current directory
            $logFilename = ExecutionContext::basename() . '.log';
        }
    }

    my $dir = ExecutionContext::directory($logFilename);
    mkdir($dir);
    return $logFilename;
}

1;
