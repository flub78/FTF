# ----------------------------------------------------------------------------
#
# Title:  File reader and writer routine
#
# Source - <file:../FileContent.pm.html>
# Version - 1.0
#
# Abstract:
#
#       ROutine to read or write the content of a file.
# ------------------------------------------------------------------------
package FileContent;

use strict;
use vars qw($VERSION @ISA @EXPORT);
use Exporter;

@EXPORT  = qw(readFile writeFile);
$VERSION = 1;
@ISA     = ("Exporter");

use Data::Dumper;

# ------------------------------------------------------------------------
# routine: readFile
#
# Reads the content of a file and returns it
#
# parameters:
# filename - file to read
#
# return: the content of the file
# ------------------------------------------------------------------------
sub readFile {
    my ($filename)   = @_;
    
    my $fd;
    open( $fd, "< $filename" ) or die("cannot open file $filename : $!");
    my $whole_file;
    while (my $buf = <$fd>) {
    	$whole_file .= $buf;
    }
    close ($fd);
    return $whole_file; 
}

# ------------------------------------------------------------------------
# routine: writeFile
#
# write the content of a variable into a file
#
# parameters:
# filename - file to write
# content - buffer to write to the file
# ------------------------------------------------------------------------
sub writeFile {
    my ($filename, $content)   = @_;

    my $fd;
    open( $fd, "> $filename" ) or croak("cannot open file $filename : $!");
    print $fd $content;
    close($fd);
}
1;
