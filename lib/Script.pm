# ------------------------------------------------------------------------
# Title:  Class Script
#
# File - Script.pm
# Version - 1.0
#
# Abstract:
#
#    Root class for the framework scripts. This module provides a root
#    class that can be derived to handle context and specific treatments.
#
#    By default every script has a logger and provides methods to 
#    log information on the script default logger.
#
#    Previous version of this class also provided a lot of not so closely related
#    services like execution context information now managed into the <ExecutionContext>
#    class and script configuration parameters from the command line of from
#    a configuration file now managed into the <ScriptConfiguration> class.    
#
# Logging:
#
#    This object uses Log4perl. Logging is done by default on a logger which has 
#    the basename of the script. Just add a line like this one in your log4perl configuration
#    file to control your logging. Without it you will not get any logs.
#
#    (start code)
#    log4perl.logger.ScriptTemplate = DEBUG, Screen, LogFile
#    (end)
#
#    The method <log4perlConfigurationFilename> defines the place of your
#    log4perl configuration file. By default it is $HOME/log4perl.conf but
#    you can replace it. It is recommended to have only one and control all
#    your logging with it.
#
#    The supplied log4perl configuration file expect the default log file
#    to be define by a routine named <logFilename>. You can replace it too
#    but be cautious, the routine must be in the main name space.
#
#    You can read the log4perl CPAN module but you do not have to, you can just
#    use the <debug>, <info>, <warn>, <error> and <fatal> which just send your logs
#    to the object default logger.
#
# Attributes:
#
#    Attributes can be provided as hash values to the constructor. If you do not
#    provide them reasonable defaults are provided.
#
#    Logger - the script default logger
# ------------------------------------------------------------------------
package Script;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use Log::Log4perl qw(:easy);
use ClassWithLogger;

$VERSION = 1;
@ISA     = qw(ClassWithLogger);


# ########################################################################
# Object Methods
# --------------

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    my %attr = @_;

    # Call the parent initialization first
    $Self->ClassWithLogger::_init(@_);

    # Takes the new parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    # reset the log file
    unlink( main::logFilename() );
}


# ------------------------------------------------------------------------
# method: doc
#
#  Log script documentation
#  Recommended levels:
#  $DEBUG - things that cannot change between executions
#  $INFO - things that can change between two executions
#
# Parameters:
#     Str - String to log
# ------------------------------------------------------------------------
sub doc {
    my ( $Self, $str, $level ) = @_;
    my $l = defined($level) ? $level : $DEBUG;
    $Self->log( $l, $str, ".Doc" );
}

1;
