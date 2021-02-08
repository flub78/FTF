# ----------------------------------------------------------------------------
#
# Title:  Class FileList
#
# File - FileList.pm
# Version - 1.1
#
# Abstract:
#
#       This package provides several services on file lists.
#       They can be used to check installations, monitor program execution, etc.
#
#       File lists are built from a root directory, they have
#       a name or short description, and contain a list of files
#       with all their attributes, owner, size, modification date, etc.
#
#       This package provide operations to build and compare
#       file lists.
# ------------------------------------------------------------------------
package FileList;

use strict;
use Exporter;
use File::Find;
use Data::Dumper;
use User::pwent;
use User::grent;
use Cwd;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK );

@ISA       = qw(Exporter);
$VERSION   = 1;
@EXPORT_OK = qw (compare);

use Log::Log4perl;

my $Logger = Log::Log4perl::get_logger("FileList");

# temporary file list, warning not thread safe
my @filelist = ();

# Group and user cache
my %userCache  = ();
my %groupCache = ();

# ------------------------------------------------------------------------
# method: new
#
# Returns a new initialised object for the class.
# ------------------------------------------------------------------------
sub new {
    my $Class = shift;
    my $Self  = {};

    bless( $Self, $Class );

    $Self->{Logger} = Log::Log4perl::get_logger($Class);
    $Self->{Logger}->debug("Creating instance");
    $Self->_init(@_);
    return $Self;
}

# ------------------------------------------------------------------------
# method: _process_file (private)
#
# Called for each file, used to fill the object data structure
# Warning: not thread safe.
# ------------------------------------------------------------------------
sub _process_file {

    # do whatever;
    if ( -d $_ ) {
        return;
    }
    push( @filelist, $File::Find::name );
}

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;
    my $log  = $Self->{Logger};

    # Initialisation
    my $root = shift;
    @filelist = ();
    $Self->{filelist} = [];

    # if the root is defined fill the file list
    if ( defined($root) ) {

        if ( substr( $root, -1) ne '/' ) {    
            $root .= '/';
        }

        $Self->{root} = $root;

        my $pwd = getcwd();

        $log->debug("Creating a file list \$root = $root, \$pwd = $pwd");
        chdir($root) or die "unknow directory $root";
        find( \&_process_file, $root );
        chdir($pwd) or die "cannot return to $pwd";

        foreach my $file (@filelist) {
            ( -e $file ) or next;
            $Self->addFile($file);
        }
    }
    else {
        $Self->{root} = "";
    }
}

# ------------------------------------------------------------------------
# method: addFile
#
# Add a file into a filelist
#
# Parameter:
#    $file - absolute path
#    $statref - reference of its stats array (optional)
# ------------------------------------------------------------------------
sub addFile {
    my ( $Self, $file, $statref ) = @_;

    push( @{ $Self->{filelist} }, $file );

    my @stats;
    if ( defined($statref) ) {
        @stats = @{$statref};
    }
    else {
        @stats = ( stat($file) );
    }
    $Self->{stats}->{$file} = \@stats;
    my (
        $dev,  $ino,   $mode,  $nlink, $uid,     $gid, $rdev,
        $size, $atime, $mtime, $ctime, $blksize, $blocks
      )
      = @stats;
    $Self->{dev}->{$file}   = $dev;
    $Self->{ino}->{$file}   = $ino;
    $Self->{mode}->{$file}  = $mode & 07777;
    $Self->{nlink}->{$file} = $nlink;
    $Self->{uid}->{$file}   = $uid;
    $Self->{user}->{$file}  = _userCache($uid);

    $Self->{gid}->{$file}   = $gid;
    $Self->{group}->{$file} = _groupCache($gid);

    $Self->{rdev}->{$file}  = $rdev;
    $Self->{size}->{$file}  = $size;
    $Self->{atime}->{$file} = $atime;
    $Self->{mtime}->{$file} = $mtime;
    $Self->{ctime}->{$file} = $ctime;
}

sub dev {my ($Self, $file) =@_; $file = $Self->absolutePath($file); return $Self->{dev}->{$file};}
sub ino {my ($Self, $file) =@_; $file = $Self->absolutePath($file); return $Self->{ino}->{$file};}
sub mode {my ($Self, $file) =@_; $file = $Self->absolutePath($file); return $Self->{mode}->{$file};}
sub nlink {my ($Self, $file) =@_; $file = $Self->absolutePath($file); return $Self->{nlink}->{$file};}
sub uid {my ($Self, $file) =@_; $file = $Self->absolutePath($file); return $Self->{uid}->{$file};}
#sub user {my ($Self, $file) =@_; $file = $Self->absolutePath($file); return $Self->{user}->{$file};}
sub gid {my ($Self, $file) =@_; $file = $Self->absolutePath($file); return $Self->{gid}->{$file};}
#sub group {my ($Self, $file) =@_; $file = $Self->absolutePath($file); return $Self->{group}->{$file};}
sub rdev {my ($Self, $file) =@_; $file = $Self->absolutePath($file); return $Self->{rdev}->{$file};}
sub size {my ($Self, $file) =@_; $file = $Self->absolutePath($file); return $Self->{size}->{$file};}
sub atime {my ($Self, $file) =@_; $file = $Self->absolutePath($file); return $Self->{atime}->{$file};}
sub mtime {my ($Self, $file) =@_; $file = $Self->absolutePath($file); return $Self->{mtime}->{$file};}
sub ctime {my ($Self, $file) =@_; $file = $Self->absolutePath($file); return $Self->{ctime}->{$file};}

# ------------------------------------------------------------------------
# method: absolutePath
#
# returns the absolute file of a file list relative path
#
# Parameter:
#    $file - file path
# Return: the absolute path
# ------------------------------------------------------------------------
sub absolutePath {
    my ( $Self, $file ) = @_;

    if ( substr( $file, 0, 1 ) ne '/' ) {
        $file = $Self->{root} . $file;
    }
    return $file;
}

# ------------------------------------------------------------------------
# method: relativePath
#
# returns the relative path of a file from a file list.
#
# Parameter:
#    $file - file absolute path
# Return: the relativee path
# ------------------------------------------------------------------------
sub relativePath {
    my ( $Self, $file ) = @_;

    my $root = $Self->{root};
    if ( $file =~ /$root(.*)/ ) {
        $file = $1;
    }
    return $file;
}

# ------------------------------------------------------------------------
# method: exist
#
# Check that a relative file exist into a file list
#
# Parameter:
#    $file - file path
#    $relative - when defined add the root in front
# Return: boolean
# ------------------------------------------------------------------------
sub exist {
    my ( $Self, $file ) = @_;

    $file = $Self->absolutePath($file);
    return ( defined( $Self->{stats}->{$file} ) );
}

# ------------------------------------------------------------------------
# routine: _userCache (private)
#
# cache user number to name conversions
# ------------------------------------------------------------------------
sub _userCache {
    my $uid = shift;
    $userCache{$uid} = getpwuid($uid)->name || "#$uid"
      unless defined $userCache{$uid};
    return $userCache{$uid};
}

# ------------------------------------------------------------------------
# routine: _groupCache (private)
#
# cache group number to name conversions
# ------------------------------------------------------------------------
sub _groupCache {
    my $gid = shift;
    $groupCache{$gid} = getgrgid($gid)->name || "#$gid"
      unless defined $groupCache{$gid};
    return $groupCache{$gid};
}

# ------------------------------------------------------------------------
# method: stats
#
# return: the file stats of a file inside a file list
# ------------------------------------------------------------------------
sub stats {
    my ( $Self, $file ) = @_;

    $file = $Self->absolutePath($file);
    return $Self->{stats}->{$file};
}

# ------------------------------------------------------------------------
# method: user
#
# Parameter:
#     $file : relative path
#
# return: the user of a file
# ------------------------------------------------------------------------
sub user {
    my ( $Self, $file ) = @_;

    $file = $Self->absolutePath($file);
    return $Self->{user}->{$file};
}

# ------------------------------------------------------------------------
# method: group
#
# Parameter:
#     $file : relative path
#
# return: the group of a file
# ------------------------------------------------------------------------
sub group {
    my ( $Self, $file ) = @_;

    $file = $Self->absolutePath($file);
    return $Self->{group}->{$file};
}

# ------------------------------------------------------------------------
# method: dump
#
# Dump the file list
#
# Parameters:
#     $prefix - something printed in front of each line
#
# return: the file list in a string format
# ------------------------------------------------------------------------
sub dump {

    my ( $Self, $prefix ) = @_;

    my $log = $Self->{Logger};

    my $res = "";
    defined($prefix) or $prefix = "";

    # Something to do
    # my $root = $Self->{root};
    # $res .= $prefix . "root => $root\n";

    foreach my $file ( @{ $Self->{filelist} } ) {
        my (
            $dev,  $ino,   $mode,  $nlink, $uid,     $gid, $rdev,
            $size, $atime, $mtime, $ctime, $blksize, $blocks
          )
          = @{ $Self->stats($file) };
        $mode &= 07777;
        $res .= "$prefix $mode ";
        $res .= _userCache($uid) . " ";
        $res .= _groupCache($gid) . " ";

        my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
          gmtime($mtime);
        $mon++;
        $year += 1900;

        $res .= "$size ";
        $res .= "$year/$mon/$mday $hour:$min:$sec ";

        $res .= $Self->absolutePath($file) . "\n";
    }
    return $res;
}

# ------------------------------------------------------------------------
# method: root
#
# return: the file list root
# ------------------------------------------------------------------------
sub root {
    my $Self = shift;
    return $Self->{root};
}

# ------------------------------------------------------------------------
# method: list
#
# return: the list of files relative to the root
# ------------------------------------------------------------------------
sub list {
    my $Self = shift;
    return @{ $Self->{filelist} };
}

# ------------------------------------------------------------------------
# method: deleted
#
# return: return a list of deleted files
# ------------------------------------------------------------------------
sub deleted {
    my ( $Self, $second ) = @_;

    my $log = $Self->{Logger};
    $log->debug("Checking for deleted files");
    my $deleted_fl = new FileList();
    foreach my $file ( @{ $Self->{filelist} } ) {
        if ( !$second->exist($file) ) {
            $log->debug("$file has been deleted");
            $deleted_fl->addFile( $file, $Self->stats($file) );
        }
        else {
            $log->debug("$file has not been deleted");
        }
    }
    return $deleted_fl;
}

# ------------------------------------------------------------------------
# method: created
#
# return: return a list of created files
# ------------------------------------------------------------------------
sub created {
    my ( $Self, $second ) = @_;

    my $log = $Self->{Logger};
    $log->debug("Checking for created files");
    my $created_fl = new FileList();
    foreach my $file ( @{ $second->{filelist} } ) {
        if ( !$Self->exist($file) ) {
            $log->debug("$file has been created");
            $created_fl->addFile( $file, $second->stats($file) );
        }
        else {
            $log->debug("$file has not been created");
        }
    }
    return $created_fl;
}

# ------------------------------------------------------------------------
# method: updated
#
# return: return a list of updated files
# ------------------------------------------------------------------------
sub updated {
    my ( $Self, $second ) = @_;

    my $log = $Self->{Logger};
    $log->debug("Checking for updated files");

    my $updated_fl = new FileList();
    foreach my $file ( @{ $Self->{filelist} } ) {
        if ( $second->exist($file) ) {

            $log->debug("updated checking common file $file");
            my @stat1 = @{ $Self->stats($file) };
            my @stat2 = @{ $second->stats($file) };
            for ( my $i = 0 ; $i < @stat1 ; $i++ ) {

                if ( $stat1[$i] != $stat2[$i] ) {
                    $log->debug("$file has been updated");
                    $updated_fl->addFile( $file, $second->stats($file) );
                    last;
                }
            }
        }
    }
    return $updated_fl;
}

# ------------------------------------------------------------------------
# method: equal
#
# return: compare two file lists
# TODO more efficient version
# ------------------------------------------------------------------------
sub equal {
    my ( $Self, $second ) = @_;

    my $log = $Self->{Logger};

    #    print( $Self->dump("fl 1 "),   "\n" );
    #    print( $second->dump("fl 2 "), "\n" );

    my $created = $Self->created($second);
    my $deleted = $Self->deleted($second);
    my $updated = $Self->updated($second);

    my $file;

    my $diff =
      scalar( $created->list() ) + scalar( $deleted->list() ) +
      scalar( $updated->list() );

    return ( !$diff );
}

# ------------------------------------------------------------------------
# method: save
#
# save a file list to a file
# ------------------------------------------------------------------------
sub save {
    my ( $Self, $filename ) = @_;

    my $log = $Self->{Logger};

    $log->info("saving to $filename");

    open( OUT, ">$filename" ) || die "cannot create $filename: $!";
    print( OUT Dumper($Self), "\n" );
    close(OUT) || die "can't close  $filename: $!";
    $log->info("$filename saved");
}

# ------------------------------------------------------------------------
# method: load
#
# reload a file list from a file
# ------------------------------------------------------------------------
sub load {
    my ( $Self, $filename ) = @_;

    my $log = $Self->{Logger};

    $log->info("loading $filename");

    open( IN, "<", "$filename" ) || die "cannot open $filename: $!";
    my $str;
    my $VAR1;
    while (<IN>) {
        $str .= $_;
    }
    close(IN) || die "can't close  $filename: $!";

    # print $str, "\n";
    eval($str);

    # print "\n\n VAR1 = ", Dumper ($VAR1);
    $Self = $VAR1;

    # print "\n\n Self = ", Dumper ($Self);
    $log->info("$filename loaded");
}

# ------------------------------------------------------------------------
# method: filelist_changed
#
# Returns true when a file list has changed. It could be file creation,
# deletion, change of size or modification time.
#
# Parameters:
# $dir - the directory to monitor
# $initial_fl - the initial file list to compare to
# $new_fl_ref - a reference to the file list after call
# ------------------------------------------------------------------------
sub filelist_changed {
    my ($dir, $initial_fl, $new_fl_ref) = @_;
    
    $$new_fl_ref = new FileList($dir);
    return !( $initial_fl->equal($$new_fl_ref) );
}

# ------------------------------------------------------------------------
# method: filelist_stabilized
#
# Returns true when a file list does not change any more between two
# periods. It means that files and files attributs are constant.
#
# Parameters:
# $dir - the directory to monitor
# $previous_ref - reference to the file list before call
# $current - a reference to the file list after call
# ------------------------------------------------------------------------
sub filelist_stabilized {
    my ($dir, $previous_ref, $current_ref) = @_;
    
    $$current_ref = new FileList($dir);
    if ( $$previous_ref->equal($$current_ref) ) {
        return 1;
    } else {
        $$previous_ref = $$current_ref;
        return 0;
    };
}

1;
