# ----------------------------------------------------------------------------
#
# Title: Class Reporters::TestResultParser
#
# Name:
#
#    package Reporters::TestResultParser
#
# Abstract:
#
#    Test result parser. After the test result parsing.
#    Provide a high level interface to test results.
#    This class is the only one to knows about the test report
#    format.
# ----------------------------------------------------------------------------
package Reporters::TestResultParser;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Exporter;
use Log::Log4perl;
use Data::Dumper;

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

    $Self->{Logger} = Log::Log4perl::get_logger($Class);
    $Self->{Logger}->debug("Creating instance of $Class");
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
    $Self->reset();

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
# method: reset
#
# Initialisation
# ------------------------------------------------------------------------
sub reset {
    my $Self = shift;
    $Self->{'global'}     = 'NOT_FOUND';
    $Self->{'success'}    = 0;
    $Self->{'failures'}   = 0;
    $Self->{'synopsis'}   = "";
    $Self->{'lineNumber'} = 0;
    $Self->{'doc'}        = "";
    $Self->{'counters'}   = "";
    $Self->{'variable'}   = {};
    $Self->{'expected'}   = 0;

    $Self->{'table_list'}     = [];
    $Self->{'table_idx'}      = {};
    $Self->{'table_idx_list'} = {};
    $Self->{'table_values'}   = {};
}

sub trim {
    my @out = @_;
    for (@out) {
        s/^\s+//;
        s/\s+$//;
    }
    return wantarray ? @out : $out[0];
}

# ----------------------------------------------------------------------------
# method: counter_line
#
# Process a counter line. There are two kinds of counters:
#    - scalar counters
#    - two dimensions tables
# There is no way of knowing if a variable is a scalar or a table
# so they are all managed as tables, eventually with only one element.
#
# Question: must we manage multiple values on the same line as the same
# values on different lines.
#
# Reply: probaly not, when there are several values they belong to
# the same table.
#
# Exemple:
# (start code)
#2009/11/11 17:09:18 : IterationTime = 0.00119709968566895, Iteration = 94
#2009/11/11 17:09:18 : IterationTime = 0.00123405456542969, Iteration = 95
#2009/11/11 17:09:18 : IterationTime = 0.00122690200805664, Iteration = 96
#2009/11/11 17:09:18 : IterationTime = 0.00122904777526855, Iteration = 97
#2009/11/11 17:09:18 : IterationTime = 0.00397396087646484, Iteration = 98
#2009/11/11 17:09:18 : IterationTime = 0.0011899471282959, Iteration = 99
#2009/11/11 17:09:18 : IterationTime = 0.00122594833374023, Iteration = 100
#
#2009/11/11 17:09:18 : TotalTime = 0.157356023788452
#2009/11/11 17:09:18 : Iterations = 100
#2009/11/11 17:09:18 : AverageIterationTime = 0.00157356023788452
#2009/11/11 17:09:18 : MaxIterationTime = 0.00433182716369629
#2009/11/11 17:09:18 : MinIterationTime = 0.00118708610534668
#
# variable:     counter("MinIterationTime") = 0.00118708610534668
#
# Table:        table ("IterationTime.Iteration")
# (end)
#
# When a value is repeated, there are several global interpretations:
#   - addition for number of messages or time
#   - min or max
#   - have no global meaning like average or iteration
#   - be a variation of the same measure (memory, CPU)
# 
# Parameters:
#    $date - string containing a date
#    $what - the counter line
# ----------------------------------------------------------------------------
sub counter_line {
    my ( $Self, $date, $what ) = @_;

    $Self->{'counters'} .= $date . ": " . $what . "\n";

    # list is a list of values for the table
    my @values    = ($date);
    # colNames is the list of columns
    my @colNames = ("date");
    foreach my $affect ( split( /, /, $what ) ) {
        if ( $affect =~ /\s*(.*)\s*=\s*(.*)\s*/ ) {
            my $variable = trim($1);
            my $value    = trim($2);
            push( @values, $value );
            push( @colNames, $variable );
        }
    }

    # The name of the table is the dot separated list of variables
    my $tableName = trim(join (".", @colNames));
    
    # name is the name of the table
    if ( exists( $Self->{'table_values'}->{$tableName} ) ) {
        # add a new line
        push( @{ $Self->{'table_values'}->{$tableName} }, \@values );
    }
    else {
        # create the entry
        $Self->{'table_values'}->{$tableName} = [\@values];
        my $cnt = 0;
        foreach my $idx (@colNames) {
            $Self->{'table_idx'}->{$tableName}->{$idx} = $cnt;
        }
        $Self->{'table_idx_list'}->{$tableName} = \@colNames;
        push( @{ $Self->{'table_list'} }, $tableName );
    }
}

# ----------------------------------------------------------------------------
# method: counter_list
#
# Return the list of counters of a test
# ----------------------------------------------------------------------------
sub counter_list {
    my ($Self) = @_;

    my @list = ();
    foreach my $tbl (@{$Self->{'table_list'}}) {
        if (($Self->table_size($tbl) == 1) && 
            (scalar($Self->table_columns($tbl)) == 2) ) {
            push (@list, $tbl);
        }
    }
    return @list;
}

# ----------------------------------------------------------------------------
# method: table_list
#
# Return the list of tables of a test
# ----------------------------------------------------------------------------
sub table_list {
    my ($Self, $all) = @_;

    return @{$Self->{'table_list'}} if $all;
    
    my @list = ();
    foreach my $tbl (@{$Self->{'table_list'}}) {
        if ($Self->table_size($tbl) > 1) {
            push (@list, $tbl);
        }
    }
    return @list;
}

# ----------------------------------------------------------------------------
# method: table_columns
#
# Return the list of columns of a table
# ----------------------------------------------------------------------------
sub table_columns {
    my ($Self, $table) = @_;

    return undef unless exists($Self->{'table_idx_list'}->{$table});
    return @{$Self->{'table_idx_list'}->{$table} };
}

# ----------------------------------------------------------------------------
# method: table_index
#
# Return the index of a column in a table
# ----------------------------------------------------------------------------
sub table_index {
    my ($Self, $table, $col) = @_;

    if (exists($Self->{'table_idx_values'}->{$table}->{$col})) {
        return $Self->{'table_idx_values'}->{$table}->{$col};
    }
    my @colNames = $Self->table_columns($table);
    my $cnt = 0;
    foreach my $col (@colNames) {
        $Self->{'table_idx_values'}->{$table}->{$col} = $cnt;
        $cnt++;
    }
    if (exists($Self->{'table_idx_values'}->{$table}->{$col})) {
        return $Self->{'table_idx_values'}->{$table}->{$col};
    } else {
        return -1;
    }
}

# ----------------------------------------------------------------------------
# method: table_size
#
# Return the number of lines of a table
# ----------------------------------------------------------------------------
sub table_size {
    my ($Self, $table) = @_;

    return 0 unless exists($Self->{'table_idx_list'}->{$table});
    return scalar@{$Self->{'table_values'}->{$table}};
}

# ----------------------------------------------------------------------------
# method: table_value
#
# Return the value of a cell in a table.
#
# Parameters:
#    $table - name of the table
#    $col   - column name
#    $line  - line number
# ----------------------------------------------------------------------------
sub table_value {
    my ($Self, $table, $col, $line) = @_;

    my $idx = $Self->table_index($table, $col);
    return undef if ($idx < 0);
    
    my $size = $Self->table_size($table);
    return undef if (($line < 0) || ($line >= $size));
    
    my @row = @{$Self->{'table_values'}->{$table}}[$line];
    return $row[0][$idx];
}

# ----------------------------------------------------------------------------
# method: counter_value
#
# Return the value of a cell in a counter.
#
# Parameters:
#    $table - name of the table
#    $col   - column name
# ----------------------------------------------------------------------------
sub counter_value {
    my ($Self, $table, $col) = @_;

    my $idx;

    if (defined($col)) {
        $idx = $Self->table_index($table, $col);
    } else {
        # default
        $idx = $Self->table_index($table, $table);
    }
    return undef if ($idx < 0);
    
    my @row = @{$Self->{'table_values'}->{$table}}[0];
    return $row[0][$idx];
}


# ----------------------------------------------------------------------------
# method: load
#
# Scan a test result file and store the extracted data
# ----------------------------------------------------------------------------
sub load {
    my ( $Self, $filename ) = @_;

    $Self->{Logger}->trace("load( $filename )");
    $Self->reset();

    $Self->{'filename'} = $filename;
    open( FD, "< $filename" ) or die("cannot open file $filename : $!");
    $Self->{'global'} = 'ABORTED';
    while ( my $line = <FD> ) {
        chomp($line);

        if ( $line =~ /Test.Checks/ ) {
print "$line\n";
            # it is an assertion check
            if ( $line =~
/Test.Checks\s\:\s(PASSED|FAILED)\s(global)\s(.*), success=(\d*), failures=(\d*)/
              )
            {

                # it is the global report
                $Self->{'global'}      = $1;
                $Self->{'declared_id'} = $3;
                $Self->{'success'}     = $4;
                $Self->{'failures'}    = $5;
            }
            else {

                # it is a sub-test
                if ( $line =~ /PASSED/ ) {
                    $Self->{'success'}++;
                }
                else {
                    $Self->{'failures'}++;
                }
            }
        }
        elsif ( $line =~ /(.*)Test.Doc\s:\s(.*)/ ) {

            # documentation line
            my $doc = $2;
            if ( $doc =~ /(.*)\s=\s*(.*)/ ) {
                # variable affectation
                $Self->{'variable'}->{$1} = $2;
            }
            else {
                $Self->{'doc'} .= $doc . "\n";
            }

        }
        elsif ( $line =~ /(.*)\INFO(.*)Test.Counters\s:\s(.*)/ ) {

            # counter line
            $Self->counter_line( $1, $3 );

        }
        else {

            # other lines are not used to build reports
            # print $line, "\n";
        }
        $Self->{lineNumber}++;
    }
    close FD;

    my (
        $dev,  $ino,   $mode,  $nlink, $uid,     $gid, $rdev,
        $size, $atime, $mtime, $ctime, $blksize, $blocks
    ) = stat($filename);
    $Self->{'startTime'} = $ctime;
    $Self->{'endTime'}   = $mtime;
}

# ----------------------------------------------------------------------------
# method: globalStatus
#
#    Set or Get the global status of a test.
#
#    PASSED, FAILED, ABORTED, NOT_FOUND
# ----------------------------------------------------------------------------
sub globalStatus {
    my ($Self) = @_;

    return $Self->{'global'};
}

# ----------------------------------------------------------------------------
# method: passedSubTests
#
#    Returns:
#
#    the number of passed sub-tests
# ----------------------------------------------------------------------------
sub passedSubTests {
    my ($Self) = @_;

    return $Self->{'success'};
}

# ----------------------------------------------------------------------------
# method: failedSubTests
#
#
# ----------------------------------------------------------------------------
sub failedSubTests {
    my ($Self) = @_;

    return $Self->{'failures'};
}

# ----------------------------------------------------------------------------
# method: requirements
#
#    Returns:
#
#    The list of requirements covered by the test. It may be different from the test case one because the check of some requirements may be dynamic and depends on the input parameters
# ----------------------------------------------------------------------------
sub requirements {
    my ($Self) = @_;
    
    return [];
}

# ----------------------------------------------------------------------------
# method: addRequirements
#
#    Add a new requirement to the test case
# ----------------------------------------------------------------------------
sub addRequirements {
    my ( $Self, $req ) = @_;
}

# ----------------------------------------------------------------------------
# method: startTime
#
#    Set or get the test execution start time (the result file creation date).
#
#    Returns:
#    The time
# ----------------------------------------------------------------------------
sub startTime {
    my ($Self) = @_;

    return $Self->{'startTime'};
}

# ----------------------------------------------------------------------------
# method: endTime
#
#    Set or get the test completion time (the file result last access time).
# ----------------------------------------------------------------------------
sub endTime {
    my ($Self) = @_;

    return $Self->{'endTime'};
}

# ----------------------------------------------------------------------------
# method: filename
#
#    Returns the name of the test log file
# ----------------------------------------------------------------------------
sub filename {
    my ($Self) = @_;
    return $Self->{'filename'};
}

# ----------------------------------------------------------------------------
# method: synopsis
#
#    Returns the test synopsis
# ----------------------------------------------------------------------------
sub synopsis {
    my ($Self) = @_;

    if ( exists( $Self->{'variable'}->{'Synopsis'} ) ) {
        return $Self->{'variable'}->{'Synopsis'};
    }
    else {
        return $Self->{'synopsis'};
    }
}

# ----------------------------------------------------------------------------
# method: doc
#
#    Returns the free text documentation
# ----------------------------------------------------------------------------
sub doc {
    my ($Self) = @_;
    return $Self->{'doc'};
}

# ----------------------------------------------------------------------------
# method: counters
#
#    Returns the counters documentation
# ----------------------------------------------------------------------------
sub counters {
    my ($Self) = @_;
    return $Self->{'counters'};
}

# ----------------------------------------------------------------------------
# method: variable
#
#    Returns the variable documentation
# ----------------------------------------------------------------------------
sub variable {
    my ( $Self, $name ) = @_;
    return $Self->{'variable'}->{$name};
}

# ----------------------------------------------------------------------------
# method: dump
#
#    Returns a string image of the object
# ----------------------------------------------------------------------------
sub dump {
    my ($Self) = @_;

    return Dumper($Self);
}

1;
