# ----------------------------------------------------------------------------
# Title:  corba
#
# File - Tcl/corba.pm
# Version - 1.0
#
# Abstract:
#
#       Binding for the Tcl ORB combat.
#
# ------------------------------------------------------------------------

########################################################################

package corba;

use strict;
use lib "$ENV{'FTF'}/lib";
use vars qw($AUTOLOAD %ok_field);
use vars qw($VERSION @ISA @EXPORT);

use Exporter;
use Log::Log4perl;
use TestTools::Tcl::Combat;
use Error qw(:try);

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
    $Self->{Logger}->debug("Creating instance");
    $Self->_init(@_);

    return $Self;
}


# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self   = shift;

    # Initialisation
    my ($tclref) = @_;
    $Self->{TclRef} = $tclref;
}

# ------------------------------------------------------------------------
# method: AUTOLOAD
#
#     This method catch any undeclared method and translate it into
#     Tcl code.
# Warning: The issue with this code is that it let the Tcl layer check
# tha validity of the call.
# ------------------------------------------------------------------------
sub AUTOLOAD {
    my $Self   = shift;
    my $method = $AUTOLOAD;
    
    my $log = $Self->{Logger};
    $log->info("auto-loading method $method");
    
    my $paramStr = join (" ", @_);
    my @name = split(/::/, $AUTOLOAD);
    my $cmd = "$Self->{'TclRef'} $name[1] $paramStr"; 

    $log->info("Eval $cmd");
    return (Combat::Eval($cmd));
}

sub DESTROY {}

# ------------------------------------------------------------------------
# method: string_to_object
#
# Returns a CORBA object reference
# ------------------------------------------------------------------------
sub string_to_object {
    my $str = shift;
    
    my $cmd = "corba::string_to_object $str";
    return new corba (Combat::Eval($cmd));
}


# ------------------------------------------------------------------------
# method: resolve_initial_references
#
# Returns a CORBA object reference
# ------------------------------------------------------------------------
sub resolve_initial_references {
    my $str = shift;
    
    my $cmd = "corba::resolve_initial_references $str";
    return new corba (Combat::Eval($cmd));
}


# ------------------------------------------------------------------------
# method: init
#
# Initialize the ORB
# ------------------------------------------------------------------------
sub init {
    my $argv = shift;
    
    my $cmd = "eval corba::init $argv";
    
    return $Combat::tcl->Eval($cmd);
}
    
1;
