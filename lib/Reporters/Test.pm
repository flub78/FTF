# ----------------------------------------------------------------------------
#
# Title: Class Reporters::Test
#
# File - Reporters/Test.pm
# Version - 1.0
# Author - frederic
#
# Name:
#
#    package Reporters::Test
#
# Abstract:
#
#    Test case. Element of a test case list.
#
# ----------------------------------------------------------------------------
package Reporters::Test;

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
  my $Self = {};

  bless ($Self, $Class);

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

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    # Others initialisation
}


# ----------------------------------------------------------------------------
# method: synopsis
#
#    Returns:
#    
#    The test short description
# ----------------------------------------------------------------------------
sub synopsis {
    my ($Self) = @_;

    my $tl = $Self->{"test_list"};
    my $syn_col = $tl->column($tl->synopsis());
    return undef if ($syn_col < 0);
    
    return $tl->cell(
        $Self->{'line'},
        $syn_col
    );
}

# ----------------------------------------------------------------------------
# method: testId
#
#    Returns:
#    
#    The test identification
# ----------------------------------------------------------------------------
sub testId {
    my ($Self) = @_;
    
    my $tl = $Self->{"test_list"};
    my $syn_col = $tl->column($tl->testId());
    return undef if ($syn_col < 0);
    
    return $tl->cell(
        $Self->{'line'},
        $syn_col
    );
}

# ----------------------------------------------------------------------------
# method: select
#
#    Select or unselect a test
#    
#    Parameters:
#    $value - boolean value to select or unselect a test (optional)
#    
#    Returns:
#    True when the test is selected.
# ----------------------------------------------------------------------------
sub select {
    my ($Self, $value) = @_;

    $Self->{Logger}->trace("select");    
    my $tl = $Self->{"test_list"};
    my $syn_col = $tl->column($tl->selector());
    return undef if ($syn_col < 0);
    
    return $tl->cell(
        $Self->{'line'},
        $syn_col
    );
}

# ----------------------------------------------------------------------------
# put double quotes around arguments with spaces
# ----------------------------------------------------------------------------
sub normalize {
    my ($str) = @_;
 
    return $str if ($str =~ /\".*\"/);
    
    my @list = split (" ", $str);
    return "\"$str\"" if (scalar(@list) > 1);        
    return $str;
}

# ----------------------------------------------------------------------------
# method: cmdLine
#
#    Returns the command line to activate a test case.
# ----------------------------------------------------------------------------
sub cmdLine {
    my ($Self) = @_;
    
    my $cmd = "";
    my $tl = $Self->{"test_list"};
    my $eol = " \\\n\t";
    my $syn = $tl->synopsis();
    foreach my $col ($tl->title()) {
        # print "col = \'$col\'";
        my $val = $tl->cell($Self->{'line'}, $tl->column($col));
        if ($tl->isFlag($col)) {
            if ($val =~ /Y|y|true|1/) {
                $cmd .= " -$col";
            }
        } elsif ($tl->isParameter($col) || ($col eq $syn)) {
            $cmd .= $eol . " -$col " . normalize($val) if ($val ne "");
        } elsif ($tl->isArgument($col)) {
            $cmd .= " " if ($cmd);
            $cmd .= $val;
        } elsif ($tl->isMultiple($col)) {
            # print ", ismultiple";
            my @list = split(",", $val);
            foreach my $v (@list) {
                $cmd .= $eol . " -$col $v" if ($v ne "");
            }
        } 
        # print "\n";
    }
    return $cmd;
}

# ----------------------------------------------------------------------------
# method: requirements
#
#    Returns the test requirements list
# ----------------------------------------------------------------------------
sub requirements {
    my ($Self) = @_;
}

# ----------------------------------------------------------------------------
# method: addRequirements
#
#    Add a new requirement to the test case
# ----------------------------------------------------------------------------
sub addRequirements {
    my ($Self, $req) = @_;
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

1;
