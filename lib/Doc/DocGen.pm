# ----------------------------------------------------------------------------
#
# Title:  Class DocGen
#
# File - Doc/DocGen.pm
# Version - 1.0
#
# Abstract:
#
#       Encapsulation for the documentation Generation Service.
#       This class provide services to
#
#       - Generate Document
#
#
#       - Hide API details of the underlying classes. That way it should be possible
#       to replace the documentation generation technology with a reduced impact on
#       scripts using this interface. See note below.
#
#       - Enforce a common look and feel, by hidding individual style
#       controls and by basing the documentation generation on a set
#       of templates we should produce documents with a unique graphical chart.
#
#       - Be used as examples for OpenOffice document generation.
#
#       - Simplify the interface just by enforcing conventions. For examples,
#       templates are kept by default under $FTF/templates/OpenOffice.
#
#   In fact this class derive from the OpenOffice::Doc module and it is very unlikely
#   that we propose at some point an alternative implementation with the same API based
#   on another technology. The workload associated with this project would be much higher
#   than the one that we would save by preserving our existing scripts.
#
# ------------------------------------------------------------------------
package Doc::DocGen;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use Exporter;
use Log::Log4perl;
use Data::Dumper;
use OpenOffice::OODoc;
# use Image::Size;

$VERSION = 1;

@ISA = qw(Exporter);

# ------------------------------------------------------------------------
# method: new
#
# Returns a new initialised object for the class.
# ------------------------------------------------------------------------
sub new {
    my $Class = shift;
    my $Self  = {};

    bless( $Self, $Class );

    $Self->{log} = Log::Log4perl::get_logger($Class);
    $Self->{log}->debug("Creating instance of $Class");
    $Self->_init(@_);

    return $Self;
}

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    my %attr = @_;

    # Attribute initialization

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    # doe the template file exist ?
    exists ($Self->{'template'}) or die "missing OpenOffice template";
    my $template = $Self->{'template'};    
    unless (-e $template) {
        # look for it into the default directory
        my $temp = "$ENV{'FTF'}/templates/OpenOffice/" . $template;
        my $pwd = `pwd`;
        (-e $temp) or die "Cannot find template $template $pwd";
        $Self->{'template'} = $temp;
    }
    
    # Is the result file defined ? 
    exists ($Self->{'output'}) or die "missing output filename";
    
    # Open document template
    $Self->{'archive'} = ooFile($Self->{'template'});
    $Self->{'meta'}    = ooMeta( archive => $Self->{'archive'} );
    
    $Self->{'doc'}     = ooDocument(
        archive => $Self->{'archive'},
        member  => 'content'
    );
    $Self->{'deco'} = ooDocument(
        archive => $Self->{'archive'},
        member  => 'styles'
    );
    
    $Self->{'doc'}->createImageStyle('diagramStyle');
}



# ------------------------------------------------------------------------
# method: title
#
# Meta data title accessor
#
# See OpenOfficce::Doc documentation for details
# ------------------------------------------------------------------------
sub title {
    my $Self   = shift;
    my $log = $Self->{log}->info("DocGen::title");

    # Something to do
    return $Self->{'meta'}->title(@_);
}

# ------------------------------------------------------------------------
# method: subject
#
# Meta data subject accessor
#
# See OpenOfficce::Doc documentation for details
# ------------------------------------------------------------------------
sub subject {
    my $Self   = shift;
    my $log = $Self->{log}->info("DocGen::subject");

    # Something to do
    return $Self->{'meta'}->subject(@_);
}

# ------------------------------------------------------------------------
# method: description
#
# Meta data description accessor
#
# See OpenOfficce::Doc documentation for details
# ------------------------------------------------------------------------
sub description {
    my $Self   = shift;
    my $log = $Self->{log}->info("DocGen::description");

    # Something to do
    return $Self->{'meta'}->description(@_);
}

# ------------------------------------------------------------------------
# method: keywords
#
# Meta data keywords accessor
#
# See OpenOfficce::Doc documentation for details
# ------------------------------------------------------------------------
sub keywords {
    my $Self   = shift;
    my $log = $Self->{log}->info("DocGen::keywords");

    # Something to do
    return $Self->{'meta'}->keywords(@_);
}

# ------------------------------------------------------------------------
# method: appendHeading
#
# Append a heading in the document
#
# See OpenOfficce::Doc documentation for details
# ------------------------------------------------------------------------
sub appendHeading {
    my ($Self, $level, $text) = @_;
 
    my $log = $Self->{log}->info("DocGen::appendHeading");
    my @headings = ('Titre', 'Titre 1', 'Titre 2', 'Titre 3', 'Titre 4', );
 
    # Something to do
    return $Self->{'doc'}->appendHeading(
        style => $headings[$level],
        text  => $text,
        level => $level
    );
}

# ------------------------------------------------------------------------
# method: appendParagraph
#
# Append a paragraph in the document
#
# See OpenOfficce::Doc documentation for details
# ------------------------------------------------------------------------
sub appendParagraph {
    my $Self = shift;
 
    my $log = $Self->{log}->info("DocGen::appendParagraph");
 
    # Something to do
    return $Self->{'doc'}->appendParagraph(@_);
}

# ------------------------------------------------------------------------
# method: appendImage
#
# Append a picture in the document
#
# See OpenOfficce::Doc documentation for details
# ------------------------------------------------------------------------
sub appendImage {
    my ($Self, $img) = @_;
 
    my $log = $Self->{log}->info("DocGen::appendImage");
 
 	# print "size of $img =", imgsize($img), "\n";
	# withour size, the default is really small
	# 100% size is 100% of the page size
    my $imgElement = $Self->{'doc'}->createImageElement(
        $img,
        'description' => "description of $img",
        'import' => $img,
#        'size' => '17cm, 17cm',
        'size' => '50%, 50%',
        'style' => 'diagramStyle'
    );
#	print '-' x 80, "\n";
#	print Dumper($imgElement), "\n";
#	print '-' x 80, "\n";
	
    return $imgElement;
}


sub appendTable     {my $Self = shift; return $Self->{'doc'}->appendTable(@_)}
sub cellValue       {my $Self = shift; return $Self->{'doc'}->cellValue(@_)}
sub copyRowToHeader {my $Self = shift; return $Self->{'doc'}->copyRowToHeader(@_)}
sub deleteRow       {my $Self = shift; return $Self->{'doc'}->deleteRow(@_)}

# ------------------------------------------------------------------------
# method: save
#
# save the document
#
# See OpenOfficce::Doc documentation for details
# ------------------------------------------------------------------------
sub save {
    my $Self = shift;
 
    my $log = $Self->{log}->info("DocGen::save");
 
    # Something to do
    return $Self->{'archive'}->save(@_);
}

# ------------------------------------------------------------------------
# method: dump
#
# print an ASCII representation of the object
# ------------------------------------------------------------------------
sub dump {
    my $Self = shift;

    print Dumper($Self), "\n";
}

# ------------------------------------------------------------------------
# method: newTable
#
# create a new table in the document
#
# Parameters:
#    $tableName    - table name
#    $lines   - number of lines
#    $columns - number of columns
# ------------------------------------------------------------------------
sub newTable {
    my ($Self, $tableName, $lines, $columns) = @_;

    my $table = $Self->{'doc'}->appendTable($tableName, $lines, $columns);
    $Self->{'table_lines'}->{$tableName} = 0;
    return $table;
}

# ------------------------------------------------------------------------
# method: fillTableRow
#
# add a new line to a table
#
# Parameters:
#    $name    - table
#    $values  - reference to a list of values
# ------------------------------------------------------------------------
sub fillTableRow {
    my ($Self, $table, $values) = @_;

    my $tableName = $Self->{'doc'}->tableName($table);
    
    my $col = 0;
    my $line =  $Self->{'table_lines'}->{$tableName};
    foreach my $cellValue (@{$values}) {
        $Self->{'doc'}->cellValue($table, $line, $col, $cellValue);
        $col++;
    }
    $Self->{'table_lines'}->{$tableName}++;
}

# ------------------------------------------------------------------------
# method: copyTableStyle
#
# Copy the style of a table into another table. The two tables are
# supposed to have the same number of columns, and the same kind of data
#
# Parameters:
#    $table    - table
#    $sourceTableName  - name of the table with the style to copy
# ------------------------------------------------------------------------
sub copyTableStyle {
    my ($Self, $table, $sourceTableName) = @_;

    my $tableName = $Self->{'doc'}->tableName($table);
    my $sourceTable = $Self->{'doc'}->getTable($sourceTableName);
    
    # copy the style
    my $style = $Self->{'doc'}->tableStyle($sourceTable);
    $Self->{'doc'}->tableStyle($table, $style);
    
    # determine the number of row
    my ($rows, $columns) = $Self->{'doc'}->getTableSize($table);
    # print "applying $sourceTableName (row=$rows, columns=$columns) style=$style\n";
    for (my $col = 0; $col < $columns; $col++) {
        # Apply the column style to all columns (including width)
        my $style = $Self->{'doc'}->columnStyle ($sourceTable, $col);
        $Self->{'doc'}->columnStyle ($table, $col, $style);
      
        # Apply the cell style
        for (my $row = 0; $row < $rows; $row++) {
            my $cellrow = ($row > 0) ? 1 : 0;
            my $cellstyle = $Self->{'doc'}->cellStyle ($sourceTable, $cellrow, $col);
            # print "cellstyle ($row, $col) = $cellstyle\n";
            $Self->{'doc'}->cellStyle ($table, $row, $col, $cellstyle);
        }
    }
    
    # DEBUG, print the list of tables
    foreach my $tbl ($Self->{'doc'}->getTableList()) {
        # print $Self->{'doc'}->tableName($tbl), "\n";
    }
}


1;
