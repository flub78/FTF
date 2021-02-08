# ----------------------------------------------------------------------------
# Title: Class Range
#
# File - Range.pm
# Version - 1.0
# Author - fpeignot
#
# Abstract:
#
#    Utility class used to handle ranges, merge them, etc.
#
#    In our context ranges are a suite of pair of integers. In the pair, the
#    first value is the lower bound, the second one is the upper bound.
#
#    An interval can be continuous, in this case ithere is only one pair in the
#    list. It must be possible to check if a value belongs to an interval.
#
#    Ranges operators are overloaded to support a more natural syntax
#
# API Example:
#    (start code)
#    my $left = new Range (100, 200, 300, 400);
#    my $right = new Range (150, 250, 350, 450);
#
#    my $union = $left + $right;
#    my $intersection = $left * $right;
#
#    print $left . " union " . $right . " = " . $union . "\n";
#    print $left . " intersection " . $right . " = " . $intersection . "\n";
#    (end)
#
# Implementation:
#
#    Internaly a range is managed as an ordered list of boundaries. They are
#    the limits of the segments. They are two flags for each boundary to specify
#    if they are the beginnning or the end of a segment.
#
# Example:
# (start code)
#   The segment 10..15, 16..20, 50..50, 100..150
#   will be manage in the following list
#
#   value   isStart isEnd   End
#    10     true    false    20
#    20     false   true
#    50     true    true     50
#   100     true    false   150
#   150     false   true
#
# (end)
# ----------------------------------------------------------------------------
package Range;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Exporter;
use Log::Log4perl;
use Data::Dumper;

use overload (
    '""'  => 'toString',
    '<=>' => 'equal',
    '=='  => 'equal',
    '!='  => 'different',
    'cmp' => 'equal',
    '+'   => 'union',
    '*'   => 'intersection'
);

use constant true  => 1;
use constant false => 0;

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

    # Ranges are low level objects, logger are significant overhead 
    # for this kind of objects.
    # $Self->{Logger} = Log::Log4perl::get_logger($Class);
    # $Self->{Logger}->debug("Creating instance of $Class");
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

    my @ranges = sort { $a <=> $b } (@_);

    # default value
    $Self->{'hexadecimal'} = 0;

    # If the range is specified inside a string
    if ( scalar(@ranges) == 1 ) {
        my $str = $ranges[0];

        my @allRanges = split( /\s*,\s*/, $str );
        @ranges = ();
        foreach my $rge (@allRanges) {
            my @boundaries = split( /\s*\.\.\s*/, $rge );
            push( @ranges, @boundaries );
        }

        # normalize hexa values
        my $cnt = 0;
        foreach my $val (@ranges) {
            if ( $val =~ /0x[0-9A-Fa-f]+/ ) {
                $ranges[$cnt] = hex($val);
                $Self->{'hexadecimal'} = 1;
            }
            $cnt++;
        }
    }

    # check for an even number of boundaries
    ( scalar(@ranges) % 2 ) and die "interval require an even number of number";

    # Check that the range is ordered
    for ( my $i = 0 ; $i < scalar(@ranges) - 1 ; $i += 2 ) {
        my $low  = $ranges[$i];
        my $high = $ranges[ $i + 1 ];
        ( $low <= $high ) or die "ranges must be sorted ($low > $high)";
    }

    $Self->{'lowBound'} = [];
    my $cnt = -1;
    for ( my $i = 0 ; $i < scalar(@ranges) - 1 ; $i += 2 ) {
        my $low  = $ranges[$i];
        my $high = $ranges[ $i + 1 ];

        ( $low <= $high ) or die "ranges must be sorted ($low > $high)";

        if ( $cnt < 0 ) {
            push( @{ $Self->{'lowBound'} }, $low );
            $Self->{'highBound'}->{$low} = $high;
            $cnt++;
        }
        else {
            my $previousLow  = @{ $Self->{'lowBound'} }[$cnt];
            my $previousHigh = $Self->{'highBound'}->{$previousLow};

            if ( $low <= $previousHigh + 1 ) {

                # just merge with the previous
                $Self->{'highBound'}->{$previousLow} = $high;
            }
            else {
                push( @{ $Self->{'lowBound'} }, $low );
                $Self->{'highBound'}->{$low} = $high;
                $cnt++;
            }
        }
    }
}

# ------------------------------------------------------------------------
# method: hexadecimal
#
# hexadecimal attribute accessor. When this boolean is true the rang
#
# Parameters:
# value - when void the method get the value. when defined, set the value.
# ------------------------------------------------------------------------
sub hexadecimal {
    my $Self = shift;

    $Self->{'hexadecimal'} = shift if @_;    
    return $Self->{'hexadecimal'};
}

# ----------------------------------------------------------------------------
# method: isContinuous
#
# Retruns true when the range is continuous (only one segment).
#
# Return: a boolean
# ----------------------------------------------------------------------------
sub isContinuous {
    my $Self = shift;

    if ( scalar( @{ $Self->{'lowBound'} } ) < 2 ) {
        return 1;
    }
    else {
        return 0;
    }
}

# ----------------------------------------------------------------------------
# method: _normalize (private)
#
# Merge two list into a normalize format. The normalized format is the merged
# ordered list of all the boundaries of the two ranges. The kind table
# specifies if these boundaries are start or end of segments. A boundary can be
# both, start and end.
#
# Parameters
#   $right - second operand
# ----------------------------------------------------------------------------
sub _normalize {
    my ( $Self, $right ) = @_;

    $Self->{'boundaries'} = [];
    $Self->{'kind'}       = {};

    foreach my $range ( $Self, $right ) {
        foreach my $low ( @{ $range->{'lowBound'} } ) {

            # start = pre-increment
            if ( exists( $Self->{'kind'}->{'start'}->{$low} ) ) {
                $Self->{'kind'}->{'start'}->{$low}++;
            }
            else {
                push( @{ $Self->{'boundaries'} }, $low );
                $Self->{'kind'}->{'start'}->{$low} = 1;
            }

            #            if (!exists( $Self->{'kind'}->{'end'}->{$low} )) {
            #                $Self->{'kind'}->{'end'}->{$low} = false;
            #            }

            # end = post-increment
            my $high = $range->{'highBound'}->{$low};
            if ( exists( $Self->{'kind'}->{'start'}->{$high} ) ) {
                $Self->{'kind'}->{'end'}->{$high}--;
            }
            else {
                push( @{ $Self->{'boundaries'} }, $high );
                $Self->{'kind'}->{'end'}->{$high} = -1;
            }

            # $Self->{'kind'}->{'end'}->{$high} = true;
        }
    }
    @{ $Self->{'boundaries'} } =
      sort { $a <=> $b } ( @{ $Self->{'boundaries'} } );
}

# ----------------------------------------------------------------------------
# method: _merge
#
# Compute the union or intersection of two ranges. The algorithm just maintains
# a counter which is incremented for each start and decremented for each
# end. The union range is equivalent to level >= 1 and the intersection range
# is equivalent to level == 2.
#
# (start code)
# level
#  2           |E|      |-----E|
#              | |      |      |
#  1     ------|S|------|S     |--E|
#        |                         |
#  0 ----|S                        |-----------
# (end)
#
# Parameters
#   $right - another range to compare to
#   $limit - 1 for union, 2 for intersection
# ----------------------------------------------------------------------------
sub _merge {

    my ( $Self, $right, $limit ) = @_;

    $Self->_normalize($right);

    my @union = ();    # union or intersection, depending on $limit

    my $level = 0;
    foreach my $elt ( @{ $Self->{'boundaries'} } ) {

        # print "$elt ";
        my $pushed = 0;
        my $previous;
        if ( $Self->{'kind'}->{'start'}->{$elt} ) {
            $previous = $level;
            $level += $Self->{'kind'}->{'start'}->{$elt};

            # print "$level ";
            if ( ( $previous < $limit ) and ( $level >= $limit ) ) {

                # start of union
                # print "start ";
                push( @union, $elt );
                $pushed++;
            }
        }

        if ( $Self->{'kind'}->{'end'}->{$elt} ) {
            $previous = $level;
            $level += $Self->{'kind'}->{'end'}->{$elt};

            # print "$level ";
            if ( ( $previous >= $limit ) and ( $level < $limit ) ) {

                # end of union
                # print "stop ";
                push( @union, $elt );
            }
        }

        # print "\n";
    }
    foreach my $elt (@union) {

        # print "$elt, ";
    }

    my $rg = new Range(@union);
    return $rg;
}

# ----------------------------------------------------------------------------
# method: union
#
#    Compute the union of two ranges.
# ----------------------------------------------------------------------------
sub union {
    my ( $Self, $right ) = @_;
    return $Self->_merge( $right, 1 );
}

# ----------------------------------------------------------------------------
# method: intersection
#
#    Compute the intersection of two ranges. The intersection is null when there is no overlap.
# ----------------------------------------------------------------------------
sub intersection {
    my ( $Self, $right ) = @_;
    return $Self->_merge( $right, 2 );
}

# ----------------------------------------------------------------------------
# method: overlap
#
#    Boolean operation, true when there is an overlap
# ----------------------------------------------------------------------------
sub overlap {
    my ( $Self, $right ) = @_;

    my $null_range = new Range();
    my $intersect = $Self->_merge( $right, 2 );
    if ( $intersect == $null_range ) {
        return 0;
    }
    else {
        return 1;
    }
}

# ----------------------------------------------------------------------------
# method: belongTo
#
#    Checks if a value belong to an interval.
#
# Parameters:
#   $value - value to check
#
# Returns a boolean
# ----------------------------------------------------------------------------
sub belongTo {
    my ( $Self, $value ) = @_;

    foreach my $low ( @{ $Self->{'lowBound'} } ) {
        my $high = $Self->{'highBound'}->{$low};
        return 1 if ( $value >= $low ) and ( $value <= $high );
    }
    return 0;
}

# ----------------------------------------------------------------------------
# method: isIncluded
#
#    Check if the parameter range is included in the object.
#
#    A is included in B if (A merge B) == B.
#
# Parameters:
#   $right - range to check
# ----------------------------------------------------------------------------
sub isIncluded {
    my ( $Self, $right ) = @_;

    my $union = $Self->union($right);
    my $res   = $Self->equal($union);
    return $res;
}

# ----------------------------------------------------------------------------
# method: equal
#   Return true when two interval have the same segments.
#
# Parameters
#   $right - another range to compare to
# ----------------------------------------------------------------------------
sub equal {
    my ( $Self, $right ) = @_;
    
    if (
        scalar( @{ $Self->{'lowBound'} } ) !=
        scalar( @{ $right->{'lowBound'} } ) )
    {
        return 0;
    }
    my $idx = 0;
    foreach my $low ( @{ $Self->{'lowBound'} } ) {
        my $rightLow = @{ $right->{'lowBound'} }[$idx];
        return 0 if ( $low != $rightLow );

        my $high      = $Self->{'highBound'}->{$low};
        my $rightHigh = $right->{'highBound'}->{$low};
        return 0 if ( $high != $rightHigh );
        $idx++;
    }
    return 1;
}

# ----------------------------------------------------------------------------
# method: different
#   Return false when two interval have the same segments.
#
# Parameters
#   $right - another range to compare to
# ----------------------------------------------------------------------------
sub different {
    my ( $Self, $right ) = @_;

    return !( $Self->equal($right) );
}

# ------------------------------------------------------------------------
# method: toString
#
# print an ASCII representation of the object
# ------------------------------------------------------------------------
sub toString {
    my $Self = shift;

    my @res;

    foreach my $low ( @{ $Self->{'lowBound'} } ) {
        my $strLow = $low;
        my $strHigh = $Self->{'highBound'}->{$low};
 
        # Here I have done an interresting bug, previously $low
        # where just replaced by its hexadecimal value. In fact the iterator
        # is just a reference on the list elements and the range itself was changed.
        
        # in some aspects Perl is not better than C++ ...
        if ($Self->{'hexadecimal'}) {
            $strLow = sprintf ("0x%x", $strLow);
            $strHigh = sprintf ("0x%x", $strHigh);
        }
        push( @res, "$strLow..$strHigh" );
    }
    return join( ", ", @res );
}

1;
