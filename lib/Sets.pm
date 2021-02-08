# ----------------------------------------------------------------------------
# Title:  Class Sets
#
# File - Sets.pm
# Version - 1.0
#
# Abstract:
#
# Manages lists with unique elements. Addition of an element already present
# in the list does not change it. 
#
# Curently, it is just a set of routines to handle a regular Perl list.
# Perhaps that it would be more convenient to make it a real class with 
# addition, merge, intersection, operator overloading, etc.
# ------------------------------------------------------------------------
package Sets;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use Exporter;
use Log::Log4perl;
use Data::Dumper;

use constant TRUE  => 1;
use constant FALSE => 0;

$VERSION = 1;

@EXPORT = qw (found add_unique union intersection equals);
@ISA = qw(Exporter);


# ------------------------------------------------------------------------
# method: found
#
# Search for an element inside a list
#
# Parameters:
#   $pattern - pattern to look for
#   $listref - reference to the list
#   $useregexp - boolean, when true use a regular expression
# Return: true when found, false when not found
# ------------------------------------------------------------------------
sub found {
    my ( $listref, $pattern, $useregexp ) = @_;

    my $result = FALSE;    # not found
    foreach my $elt ( @{$listref} ) {
        if ( ( $useregexp && ( $pattern =~ $elt ) ) || ( $pattern eq $elt ) ) {
            $result = TRUE;
            last;
        }
    }
    return $result;
}

# ------------------------------------------------------------------------
# method: add_unique
#
# Push an element inside a list if it does not exist
#
# Parameters:
#   $listref - reference to the list
#   $elt     - element to add
# ------------------------------------------------------------------------
sub add_unique {
    my ( $listref, $elt ) = @_;

    found ($listref, $elt) and return;
    push (@{$listref}, $elt);
}

# ------------------------------------------------------------------------
# method: union
#
# Merge two sets
#
# Parameters:
#   $left_ref - reference to the left list
#   $right_ref - reference to the right list
# ------------------------------------------------------------------------
sub union {
    my ($left_ref, $right_ref) = @_;

    my @res = @{$left_ref};
    foreach my $elt (@{$right_ref}) {
    	add_unique (\@res, $elt);
    }
    return @res;
}

# ------------------------------------------------------------------------
# method: intersection
#
# Intersection two sets
#
# Parameters:
#   $left_ref - reference to the left list
#   $right_ref - reference to the right list
# ------------------------------------------------------------------------
sub intersection {
    my ($left_ref, $right_ref) = @_;

    my @res = ();
    foreach my $elt (@{$left_ref}) {
    	if (found($right_ref, $elt)) {
            add_unique (\@res, $elt);
    	}
    }
    return @res;
}

# ------------------------------------------------------------------------
# method: equals
#
# Checks that two sets are identical
#
# Parameters:
#   $left_ref - reference to the left list
#   $right_ref - reference to the right list
# ------------------------------------------------------------------------
sub equals {
    my ($left_ref, $right_ref) = @_;

    my $left = {};
    foreach my $elt (@{$left_ref}) {
    	$left->{$elt} = 1;
    }
    my $cnt = 0;
    foreach my $elt (@{$right_ref}) {
        return 0 unless (exists($left->{$elt}));
        $cnt++;
    }
    
    return 0 unless (scalar (keys(%{$left})) == $cnt);
    return 1;
}

1;
