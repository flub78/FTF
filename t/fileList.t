#!/usr/local/bin/perl -w

# ------------------------------------------------------------------------
# Title:  FileList Unit Test
#
# File - t/filelist.pl
# Version - 1.0
#
# Abstract:
#
#    FileList Unit Test
# ------------------------------------------------------------------------
package TestFileList;

use strict;
use lib "$ENV{'FTF'}/lib";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Test;

$VERSION = 1;
@ISA     = qw(Test);

# Test::More is only used to test Perl modules.
# use Test::More qw( no_plan );
use Data::Dumper;
use ExecutionContext;
use ScriptConfiguration;

use Test::More qw(no_plan);
use FileList;

# ------------------------------------------------------------------------
# method: TestMain
#
# Test main routine. It is this method which is executed several times
# when the *-iteration* parameter is more than 1.
# ------------------------------------------------------------------------
sub TestMain {
    my $Self = shift;

    $Self->info("Test FileList");

    # Create a controlled environment
    my $root = "/tmp/testfilelist/";
    `rm -rf $root`;
    `mkdir $root $root/subdir`;
    `touch $root/file1 $root/file2 $root/subdir/file3`;
    `ls $root > $root/subdir/list`;

    my $filenb = 4;

    # Create a file list from the directory
    my $fl = new FileList($root);

    print( $fl->dump("# ") );
    my $n = 0;    
    foreach my $f ( $fl->list() ) {
        my $str = ++$n . " : " . $f;
        print( "# ", $str, "\n" );
    }

    is( $fl->root(), $root,   "File list root" );
    is( $fl->list(), $filenb, "File list size" );

    is( $fl->exist( "/tmp/testfilelist/file1", 1 ),
        1, "Absolute file existence" );
    is( $fl->exist( "file1", 1 ), 1, "Relative file existence" );

    is( $fl->exist("/tmp/testfilelist/subdir/list"),
        1, "Absolute file existence into subdirectory" );
    is( $fl->exist("subdir/list"),
        1, "Relative file existence into subdirectory" );

    is( $fl->exist("subdir/zzzzzzz"), "", "File non existence" );

    # get current user id
    my $id = `whoami`;
    chomp($id);

    # get current group id
    my @groups = split( ' ', `groups` );

    my $file = "subdir/list";
#    print ("size = ", $fl->size($file), "\n");
    
    is( $fl->user($file), $id, "File user" );
    is( $fl->group("subdir/list"), $groups[0], "File group" );
    is( $fl->size($file), 19, "File size" );

    my $other_fl = new FileList($root);
    
    # Modify the file list
    `touch $root/file4 $root/subdir/file5`;
    `touch $root/file1`;
    `rm $root/subdir/file3`;
    `cp $root/subdir/list $root/subdir/list2`;
    `ls $root > $root/subdir/list`;

    my $fl2 = new FileList($root);

    my $fl3 = $fl->deleted($fl2);
    print("# deleted = \n");
    print( $fl3->dump("# ") );

    my $fl4 = $fl->created($fl2);
    print("# created = \n");
    print( $fl4->dump("# ") );

    my $fl5 = $fl->updated($fl2);
    print("# updated = \n");
    print( $fl5->dump("# ") );

    is( $fl->equal($fl),  1,  "File list equality" );
    my $fl_copy = $fl;
    is( $fl->equal($fl_copy),  1,  "File list equality" );
    is( $fl->equal($fl2), '', "File list difference" );
    is( $fl->equal($other_fl), 1, "File list difference" );

    $fl->save("/tmp/filelist.txt");
    $fl5->load("/tmp/filelist.txt");

    # is( $fl->equal($fl5), '', "File list difference after save/load" );
    print( $fl5->dump("# ") );
}

# ------------------------------------------------------------------------
my $configFile = ExecutionContext::configFile();
my $config     = new ScriptConfiguration(
    'scheme'     => TEST,
);

# my Test local instance.
my $test = new TestFileList();
$test->run();

