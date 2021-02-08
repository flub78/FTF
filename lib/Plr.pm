# ----------------------------------------------------------------------------
#
# Title:  Class Template
#
# Source - <file:../Class.pm.html>
# Version - 1.0
#
# Abstract:
#
#       Template for Perl classes used in the toolbox context.
#       Its usage is recommended for every class of the
#       toolbox and in test suite development.
#
# Content:
#
#       - It is an object oriented class template.
#       - Object creation and initialization are distinct. To support inheritance
#       - Accessors to set and get attribute values.
#
# Usage:
#    (start code)
#    # put here some examples of the API usage
#    my $left = new Range (100, 200, 300, 400);
#    my $union = $left + $right;
#    print $left . " union " . $right . " = " . $union . "\n";
#
# (end)
# ------------------------------------------------------------------------
package Plr;

use strict;
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use ClassWithLogger;

$VERSION = 1;
@ISA     = qw(ClassWithLogger);

use Log::Log4perl;
use Data::Dumper;

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
#
# Most constructors are organized into three steps.
#    - default attributes initialization
#    - attribute from the parameter constructor
#    - completion of attributes
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    # Call the parent initialization first
    $Self->ClassWithLogger::_init(@_);

    my %attr = @_;

    # Attribute initialization
    $Self->{'scalar'}  = 0;
    $Self->{'listRef'} = [];
    $Self->{'hashRef'} = {};

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    # Others initialisation
    unless ( exists( $Self->{'LoggerName'} ) ) {
        $Self->{'LoggerName'} = $Self->{'Class'};
    }
}

# ------------------------------------------------------------------------
# method: attr attribute accessor  
#
# This accessor can be use to set or get the value of an attribute.
#
# Parameters:
# value - when void the method get the value. when defined, set the value.
#
# (start code)
# # to set the value of an attribute 'name'
# $msg->name('Mike');
# #
# # to get tha value of the attribute
# print $msg->name();
# (end)
# ------------------------------------------------------------------------
sub attr {
    my $Self = shift;

    $Self->{'attr'} = shift if @_;
    return $Self->{'attr'};
}

# ------------------------------------------------------------------------
# method: roattr read only attribute accessor
#
# This accessor returns the value of an attribute
# ------------------------------------------------------------------------
sub roattr {
    my $Self = shift;
    return $Self->{'roattr'};
}

# ------------------------------------------------------------------------
# method: method
#
# regular method template, duplicate for each real method.
#
# parameters:
# param1 - Parameter 1
# param2 - Parameter 2
#
# return: describe the returned value
# ------------------------------------------------------------------------
sub vz {
    my ($Self, $vi)   = @_;

    # Something to do
    my $a = $Self->{'a'};
    my $b = $Self->{'b'};
    my $c = $Self->{'c'};
    
    my $vz = $a * $vi * $vi + $b * $vi + $c;
    return $vz;
}

1;
