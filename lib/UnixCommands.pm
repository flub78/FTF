# ------------------------------------------------------------------------
# Title:  Class UnixCommands
#
# File - UnixCommands.pm
# Version - 1.0
#
# Abstract:
#   Contains a set of Unix like commands to manage files and
#   directories. Most of them are only renaming of existing Perl
#   commands into names easily understandable even by Perl non
#   specialists.
# ------------------------------------------------------------------------
package UnixCommands;

use strict;

# use Test::More qw( no_plan );
use File::Compare;

# use File::Copy;
use File::Find;
use Cwd;

use vars qw($VERSION @ISA @EXPORT);
use Exporter;

$VERSION = 1;
@ISA     = ("Exporter");
@EXPORT  =
  qw(rm pushd popd cd removeQuotes delete_file cleanupDirectory waitFor cp mv);

# Directory stack for pushd and popd
my @dir_stack = [];

# ------------------------------------------------------------------------
# routine: removeQuotes
#
# Remove the double quotes from s string
# ------------------------------------------------------------------------
sub removeQuotes {
    my $str = shift;

    if ( $str =~ /^\"(.*)\"$/ ) {
        return $1;
    }
    else {
        return $str;
    }
}

# ------------------------------------------------------------------------
# method: check_existence
# ------------------------------------------------------------------------
sub check_existence {
    my $Self     = shift;
    my $FileName = shift;
    my $TestName = $Self->{Identif};
    ( -e $FileName ) or die "$TestName : $FileName doesn't exists \n";
}

# ------------------------------------------------------------------------
# method: check_Process_Done
# ------------------------------------------------------------------------
sub check_Process_Done {
    my $Self           = shift;
    my $RootProcessDir = shift;
    my $WorkDir        = shift;

    $Self->{TestStatus} = 0;
    if ( -e "$RootProcessDir/Processed/$WorkDir" ) {
        $Self->debug("SelScr : Files processed successfully");
        $Self->{TestStatus} = 1;
        return 1;
    }
    elsif ( -e "$RootProcessDir/Failed/$WorkDir" ) {
        $Self->debug("SelScr : Files failed");
        return 1;
    }
    return 0;
}

# ------------------------------------------------------------------------
#
# ------------------------------------------------------------------------
sub CheckWithRef {
    my $Self = shift;
    my ( $RefFile, $File ) = @_;

    if ( compare( $RefFile, $File ) == 0 ) {

        # Files are equal
        return 1;
    }
    else {
        $Self->{TestStatus} = 0;
        return 0;
    }

}

# ------------------------------------------------------------------------
# routine: rm
#
# Unix alias
# ------------------------------------------------------------------------
sub rm {
    my $what = shift;
    unlink <$what>;
}

# ------------------------------------------------------------------------
# routine: cd
#
# Unix alias
# ------------------------------------------------------------------------
sub cd {
    my $dir = shift;
    chdir $dir || die "cannot cd to $dir";
}

# ------------------------------------------------------------------------
# routine: pushd
#
# Unix alias
# ------------------------------------------------------------------------
sub pushd {
    my $what = shift;

    my $pwd = getcwd;
    cd $what || die "cannot change directory to $what";
    push( @dir_stack, $pwd );
}

# ------------------------------------------------------------------------
# routine: popd
#
# Unix alias
# ------------------------------------------------------------------------
sub popd {
    my $dir = pop(@dir_stack);
    chomp($dir);
    cd($dir);
}

# ------------------------------------------------------------------------
# routine: cp
#
# Unix alias
# ------------------------------------------------------------------------
sub cp {
    my ( $source, $destination ) = @_;
    my $cmd = "cp $source $destination";
    `$cmd`;
}

# ------------------------------------------------------------------------
# routine: mv
#
# Unix alias
# ------------------------------------------------------------------------
sub mv {
    my ( $source, $destination ) = @_;

    #    # print "----------- $source $destination \n";
    #    foreach my $file (<$source>) {
    #        # print "move $file $destination\n";
    #        File::copy::move ($file, $destination);
    #    }
    my $cmd = "mv $source $destination";
    `$cmd`;
}

# ------------------------------------------------------------------------
# method: _delete_file (private)
#
# delete the file
# Warning: not thread safe.
# ------------------------------------------------------------------------
sub _delete_file {

    # do whatever;
    if ( -d $_ ) {
        return;
    }

    unlink($File::Find::name);
    !( -e $File::Find::name ) or die "cannot delete $File::Find::name";
}

# ------------------------------------------------------------------------
# routine: cleanupDirectory
#
# Recursively delete all files from a directory
# ------------------------------------------------------------------------
sub cleanupDirectory {

    foreach my $dir (@_) {
        ( -d $dir ) or die "directory $dir does not exist.";
    }
    find( \&_delete_file, @_ );
}

# ------------------------------------------------------------------------
# routine: waitFor
#
# wait for a routine to return true
#
# Parameters:
#    $context - a string to identify the call
#    $polling_period - number of second between two attempts
#    $timeout - max number of occurence before giving up
#    $coderef - reference to a boolean routine (true when succesful)
#    remaining parameters - will be passed to the $coderef routine
# ------------------------------------------------------------------------
sub waitFor {

    my $Self = shift;
    my $context = shift;
    my $polling_period = shift;
    my $timeout        = shift;
    my $coderef        = shift;
    
    my $counter = 0;
    while (1) {
        $counter++;
        $Self->info($context . " " . $counter);    
        sleep($polling_period);
        last if (&$coderef(@_));
        die $context . " timeout" if ( $counter > $timeout ); 
    }
}

1;
