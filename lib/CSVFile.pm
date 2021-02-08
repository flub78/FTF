# ----------------------------------------------------------------------------
#
# Title: Class CSVFile
#
# Abstract:
#
#    Manages a comma separated values file. Provides cell access either
#    by number of by name. Lines are numbered starting at 1 like most
#    spreadsheets.
#
# ----------------------------------------------------------------------------
package CSVFile;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Exporter;
use Log::Log4perl;
use Data::Dumper;
use ClassWithLogger;

$VERSION = 1;

@ISA = qw(ClassWithLogger);

# ------------------------------------------------------------------------
# routine: removeQuotes
#
#    remove quotes around a string
# ------------------------------------------------------------------------
sub removeQuotes {
    my ($str) = @_;

    if ( $str =~ /\"(.*)\"/ ) {
        return $1;
    }
    else {
        return $str;
    }
}

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    # Call the parent initialization first
    $Self->ClassWithLogger::_init(@_);

    my %attr = @_;

    # Attribute initialization
    $Self->{'filename'}   = undef;
    $Self->{'lineNumber'} = 0;
    $Self->{'lines'}      = [];
    $Self->{'lineNames'}  = [];
    $Self->{'titleLine'}  = -1;
    $Self->{'lineName'}   = "";
    $Self->{'lineIdx'}    = -1;
    $Self->{'separator'}  = ";";

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    # Others initialisation
    if ( -f $Self->{'filename'} ) {
        $Self->load( $Self->{'filename'} );
    }
}

# ------------------------------------------------------------------------
# method: filename
#
# Filename attribut accessor
#
# Parameters:
# value - when void the method get the value. when defined, set the value.
# ------------------------------------------------------------------------
sub filename {
    my $Self = shift;

    $Self->{filename} = shift if @_;
    return $Self->{filename};
}

# ------------------------------------------------------------------------
# method: titleLine
#
# titleLine attribut accessor
#
# Parameters:
# value - when void the method get the value. when defined, set the value.
# ------------------------------------------------------------------------
sub titleLine {
    my $Self = shift;

    $Self->{titleLine} = shift if @_;
    return $Self->{titleLine};
}

# ------------------------------------------------------------------------
# method: lineNumber
#
# lineNumber attribut accessor
#
# Parameters:
# value - when void the method get the value. when defined, set the value.
# ------------------------------------------------------------------------
sub lineNumber {
    my $Self = shift;

    $Self->{lineNumber} = shift if @_;
    return $Self->{lineNumber};
}

# ----------------------------------------------------------------------------
# method: title
#
#    Returns:
#    the list of all the columns found in the title
# ----------------------------------------------------------------------------
sub title {
    my ( $Self, $idx ) = @_;

    if ( exists( $Self->{colNames} ) ) {
        if ( defined($idx) ) {
            return @{ $Self->{colNames} }[$idx];
        }
        else {
            return @{ $Self->{colNames} };
        }
    }
    else {
        return undef;
    }
}

# ----------------------------------------------------------------------------
# method: colNumber
#
#    Returns: the number of column of the title line
# ----------------------------------------------------------------------------
sub colNumber {
    my ($Self) = @_;

    if ( exists( $Self->{colNames} ) ) {
        return scalar( @{ $Self->{colNames} } );
    }
    else {
        return -1;
    }
}

# ----------------------------------------------------------------------------
# method: colName
#
#    Translate an index into a name
#
#    Parameters:
#    $index - column index
#
#    Return:
#    The name of the column (string)
# ----------------------------------------------------------------------------
sub colName {
    my ( $Self, $index ) = @_;

    return @{ $Self->{colNames} }[$index];
}

# ------------------------------------------------------------------------
# method: column
#
#  Translate a name into index
# ------------------------------------------------------------------------
sub column {
    my ( $Self, $name ) = @_;
    if ( exists( $Self->{colIndex}->{$name} ) ) {
        return $Self->{colIndex}->{$name};
    }
    else {
        return -1;
    }
}

# ----------------------------------------------------------------------------
# method: line
#
#    Set or get a line of the spreadsheet memory image.
#
#    Parameter:
#    $index - line index
#    $value - value for replacement (string)
# ----------------------------------------------------------------------------
sub line {
    my ( $Self, $index, $value ) = @_;

    # externaly line number start at 1
    $index--;
    die "$index out of range"
      unless ( $index <= $Self->lineNumber() );

    if ( defined($value) ) {
        @{ $Self->{lines} }[$index] = $value;
    }
    return @{ $Self->{lines} }[$index];
}

# ----------------------------------------------------------------------------
# method: header
#
#    Set or get the test cases list header.
#    The header is a string that describes the test cases list.
#
#    Parameters:
#    $value - optional value
#
#    Returns:
#    The header (string)
# ----------------------------------------------------------------------------
sub header {
    my ( $Self, $value ) = @_;

    my $res = "";
    for ( my $i = 1 ; $i < $Self->titleLine() ; $i++ ) {
        foreach my $cell (split( $Self->{separator}, $Self->line($i) )) {
            $res .= removeQuotes($cell) . " ";
        }
        $res .= "\n";
    }
    return $res;
}

# ----------------------------------------------------------------------------
# method: lineNames
#
#    Returns:
#    the list of all the columns found in the title
# ----------------------------------------------------------------------------
sub lineNames {
    my ( $Self, $idx ) = @_;

    if ( exists( $Self->{lineNames} ) ) {
        if ( defined($idx) ) {
            return @{ $Self->{lineNames} }[$idx];
        }
        else {
            return @{ $Self->{lineNames} };
        }
    }
    else {
        return undef;
    }
}

# ----------------------------------------------------------------------------
# method: save
#
#
# ----------------------------------------------------------------------------
sub save {
    my ( $Self, $filename ) = @_;

    # use default when none defiend
    unless ( defined($filename) ) {
        $filename = $Self->filename();
    }

    open( OUT, "> $filename" ) or die("cannot open file $filename : $!");

    # save the current filename
    $Self->filename($filename);

    foreach my $line ( @{ $Self->{lines} } ) {
        print OUT $line . "\n";
    }
    close OUT;
}

# ------------------------------------------------------------------------
# method: analyzeTitle
#
#  Analyse the title line. Once that has been done the colName and colIndex
#  methods are available; They translate respectively a column index into
#  column name and vice et versa.
# ------------------------------------------------------------------------
sub _analyzeTitle {
    my ( $Self, $line ) = @_;

    $Self->info("analyzeTitle $line");
    my $separator = $Self->{'separator'};
    my @colNames  = split( $separator, $line );
    my @names     = ();

    my $cnt = 0;
    for my $name (@colNames) {
        $name = removeQuotes($name);

        $Self->trace( "name = " . $name );
        push( @names, $name );
        $Self->{colIndex}->{$name} = $cnt;

        if ( exists( $Self->{'lineName'} ) ) {
            if ( $Self->{'lineName'} eq $name ) {
                $Self->{'lineIdx'} = $cnt;
            }
        }
        $cnt++;
    }
    $Self->{colNames} = \@names;    # be careful, there is no copy
}

# ----------------------------------------------------------------------------
# method: load
#
#
# ----------------------------------------------------------------------------
sub load {
    my ( $Self, $filename ) = @_;

    $Self->trace("load( $filename )");
    $Self->{lineNumber} = 0;

    open( FD, "< $filename" ) or die("cannot open file $filename : $!");
    $Self->{'filename'}    = $filename;
    $Self->{'after_title'} = 0;
    while ( my $line = <FD> ) {
        chomp($line);
        push( @{ $Self->{'lines'} }, $line );

       $Self->{lineNumber}++;
       if ( $Self->{lineNumber} == $Self->{titleLine} ) {
            # title line
            $Self->_analyzeTitle($line);
            $Self->{'after_title'} = 1;
            $Self->{'lineIndex'}->{'title'} = $Self->{'lineNumber'};
        }
        elsif ( $Self->{'after_title'} ) {
            # "die Dumper($Self);
            if ( $Self->{'lineIdx'} >= 0 ) {
                my @row = split ($Self->{'separator'}, $line);
                my $name = removeQuotes($row[$Self->{'lineIdx'}]);
                push (@{$Self->{'lineNames'}}, $name);
                $Self->{'lineIndex'}->{$name} = $Self->{'lineNumber'};
            }
        }
 
        if ( exists( $Self->{'last'} ) ) {
            last if ( $Self->{lineNumber} > $Self->{'last'} );
        }
    }
    close FD;
}

# ----------------------------------------------------------------------------
# method: cell
#
#
# ----------------------------------------------------------------------------
sub cell {
    my ( $Self, $row, $col, $value ) = @_;

    my @row = split( $Self->{'separator'}, $Self->line($row) );
    if ( defined($value) ) {
        $row[$col] = $value;
        $Self->line( $row, join( $Self->{'separator'}, @row ) );
    }
    return $row[$col];
}

# ----------------------------------------------------------------------------
# method: lineIndex
# ----------------------------------------------------------------------------
sub lineIndex {
    my ( $Self, $name) = @_;
    
    return $Self->{'lineIndex'}->{$name};
} 

# ----------------------------------------------------------------------------
# method: cell_by_name
# ----------------------------------------------------------------------------
sub cell_by_name {
    my ( $Self, $row, $col, $value ) = @_;

    my $row_idx = $Self->lineIndex($row); 
    my $col_idx = $Self->column($col);
    # $Self->debug("cell_by_name ($row=$row_idx, $col=$col_idx)");
    return $Self->cell($row_idx, $col_idx, $value);   
}

# ------------------------------------------------------------------------
# method: dump
#
# return an ASCII representation of the object
# ------------------------------------------------------------------------
sub dump {
    my $Self = shift;

    my $res = "";
    for ( my $i = 0 ; $i < $Self->lineNumber() ; $i++ ) {
        $res .= "| ";
        for ( my $j = 0 ; $j < $Self->colNumber() ; $j++ ) {
            if ($Self->cell( $i, $j )) {
                $res .= $Self->cell( $i, $j ) . " | ";
            } else {
                $res .= " | ";
            }
        }
        $res .= "\n";
    }
    return $res;
}

1;
