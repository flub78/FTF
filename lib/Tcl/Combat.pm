# ----------------------------------------------------------------------------
# Title:  Combat
#
# File - Tcl/Combat.pm
# Version - 1.0
#
# Abstract:
#
#       Binding for the Tcl ORB combat.
#
#       Should I supply an object interface or a package? The goal of course
#       is to supply an object interface to CORBA objects, but CORBA objects
#       will be dynamically created according to their IDL so I am not sure
#       that the combat package must be an object itself.
#
# ------------------------------------------------------------------------

########################################################################

package Combat;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use Exporter;
use Log::Log4perl;
use Tcl;
use Error qw(:try);

$VERSION = 1;

@ISA = qw(Exporter);

# ------------------------------------------------------------------------
# Creation of a Tcl interpretor
$Combat::tcl = new Tcl;    

$Combat::tcl->Init();
$Combat::tcl->SetVar( "argv", "" );

$Combat::tcl->Eval('package require combat');


# ------------------------------------------------------------------------
# method: Eval
#
# Returns a new initialised object for the class.
# ------------------------------------------------------------------------
sub Eval {
    my $str = shift;
    
    return ($Combat::tcl->Eval($str));
}


# ------------------------------------------------------------------------
# method: EvalFile
#
# Eval Tcl file in the combat context
# ------------------------------------------------------------------------
sub EvalFile {
    my $filename = shift;
    return $Combat::tcl->EvalFile($filename);
}

# ------------------------------------------------------------------------
# method: ir_add
#
# Add an interface to the interface repository
# ------------------------------------------------------------------------
sub ir_add {
    my $ir_name = shift;
    
    my $cmd = "combat::ir add $ir_name";
    return $Combat::tcl->Eval($cmd);
}

        
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
    my $Logger = $Self->{Logger};

    # Initialisation
}

# ------------------------------------------------------------------------
# method: ATTR Accessors template
#
# This accessor can be use to set or get the value of an attribute.
# You need to declare one for each attribut of your object.
#
# Parameters:
# param 1 - when void the method get the value. when defined, set the value.
#
# (start code)
# # to set a value
# $msg->name('Mike');
# #
# # to get tha value of an attribut
# print $msg->name();
# (end)
# ------------------------------------------------------------------------
sub ATTR {
    my $Self   = shift;
    my $Logger = $Self->{Logger};

    $Self->{ATTR} = shift if @_;
    return $Self->{ATTR};
}

# ------------------------------------------------------------------------
# method: METHOD method template
#
# regular method template, duplicate for each real method.
#
# parameters:
# param1 - Parameter 1
# param2 - Parameter 2
#
# return: describe the returned value
# ------------------------------------------------------------------------
sub METHOD {
    my $Self   = shift;
    my $Logger = $Self->{Logger};

    # Something to do
}

# ------------------------------------------------------------------------
# routine: Finalization block
#
#     Tcl interpretor finalization
# ------------------------------------------------------------------------
END { 
    # print   "Tcl interpretor should be destroyed here.\n" 
}
1;
