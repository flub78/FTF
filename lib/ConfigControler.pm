# ----------------------------------------------------------------------------
# Title:  Configuration File Controler
#
# File - ConfigControler.pm
# Version - 1.0
#
# Name:
#
#       package ConfigControler
#
# Abstract:
#
# This class contains a set of rules and methods to
# validate configuration files handled by AConfig objects, see <Another Configuration File Manager>.
#
# A configuration file controler has:
#   - An optional list of mandatory sections
#   - By section it has an optional list of mandatory variables
#
#   - It has an optional list of acceptable section names
#   - Per section, it has an optional list of acceptable variables names
#   - Per variable, it has an optional list of acceptable variables values
#
#   - Per section, variable and values it supports user callback
#   control functions. It means that the user can add at each level
#   its own business controls on the validity of the configuration file.
#
#   - A validate method that performs all the above checks and return
#   a report. When the report is an empty string, it means than the
#   configuration file is compliant to its rules. If there are
#   inconsistencies, the report string contains one line per error
#   with the configuration file name, the line number and the description
#   of the detected error.
#
#   When an error has no line number (like a missing section), the line
#   number is empty. For missing variables, the references line is the
#   section declaration line number.
#
#   Acceptable section names, variable names and values are specified
#   by regular expressions. The simple regular expressions are just strings
#   and in this case controler check equality. But it is possible to specify
#   more complex regular expressions to validate that a value only contains
#   a numerical digits or that section names follow a special pattern.
#
# User callbacks:
#
#   You can attach control callbacks to variables to enforce specific businesss rules. Note,
#   that you can also derive a new class from the configuration class controler to replace
#   behaviors that you do not like.
#
#   User callbacks must return TRUE when the chek is OK, and FALSE when the control fails.
#   When you attach a user callback to a variable, you must also supply an identifier for
#   the control which will be used in the error report. You can also use directly the
#   addError method to report additional problems.
#
#   The user callback is invoked with several parameters.
#   - The configuration, so you can access to the value of any parameter
#   - The configuration controler to report errors.
#   - the name of the section
#   - the name of the variable
#   - the value of the variable
#
# Requirements:
#
# - When a mandatory sections or variable list is empty, it means than
# there is no mandatory sections or variables.
#
# - Lists of acceptable section names, variables name and values can
#   contain either names or regular expressions. It allows the control that
#   section names are of the form "SECTION_XXX" with XXX as decimal digits.
#
# - The error reporting with the format filename:linenumber Error description
# can be really convenient if we want to plugg that with a GUI.
#
# Example of Report:
#
# This is the report from a CPS erroneous configuration file.
#
# (start code)
#
# cpsTest.cfg: [DIRECTORIES] - missing mandatory section
# cpsTest.cfg: [GENERAL] - missing mandatory section
# cpsTest.cfg: []cfgName - missing mandatory variable
# cpsTest.cfg: [DIRECTORIES]cpsHome - missing mandatory variable
# cpsTest.cfg:21 [DIRECTORIIIIES] - incorrect section name
# cpsTest.cfg:40 [SELECTIVE_SCRAMBLING]activate - incorrect variable name
# cpsTest.cfg:186 [GENERALITIES] - incorrect section name
# cpsTest.cfg:194 [GENERAL]scwOffsetType - >>> Invalid offset type with the encryption level
# cpsTest.cfg:356 [AUTO_ENCRYPT_CCF]period - incorrect value "ten" should be [\d+]
# cpsTest.cfg:358 [AUTO_ENCRYPT_CCF]deleteOnSuccess - incorrect value "yes" should be [true, false]
# cpsTest.cfg:360 [AUTO_ENCRYPT_CCF]encryptAlgo - incorrect value "AES" should be [NoENCRYPTION, AES-128/ECB, AES-128/CBC, DVB]
# cpsTest.cfg:440 [NODE_HTML_001] - incorrect section name
#
# (end)
#
# Usage:
# (start code)
#
#    # Load a configuration file
#    my $cfg = new Aconfig( 'filename' => 'cpsTest.cfg' );
#
#    # Create a configuration controler
#    my $ctrl = new ConfigControler ();
#
#    # Set some rules
#    $ctrl->mandatory_sections(['CLEMEInterfaces', 'DIRECTORIES', 'MISSING_SECTION']);
#    $ctrl->mandatory_variables('DIRECTORIES', ['CPS_Monitor_IOR_File', 'CPS_Manager_IOR_File', 'CPS_Controller_IOR_File']);
#    $ctrl->acceptable_sections(['BOOKMARK_PARSING', 'TIMELINE', 'AUTOMATIC_MODES_ACTIVATION']);
#
#    $ctrl->mandatory_variables('DIRECTORIES', ['cpsHome', 'cpsPath']);
#    $ctrl->mandatory_variables('SELECTIVE_SCRAMBLING', ['enable', 'extension']);
#
#    $ctrl->acceptable_variables('SELECTIVE_SCRAMBLING', ['delay']);
#
#    $ctrl->acceptable_values('AUTO_ENCRYPT_CCF', 'deleteOnSuccess', ['true', 'false']);
#    $ctrl->acceptable_values('AUTO_ENCRYPT_CCF', 'period', ['\d+']);
#    $ctrl->acceptable_values('AUTO_ENCRYPT_CCF', 'encryptAlgo', ['NoENCRYPTION', 'AES-128/ECB', 'AES-128/CBC', 'DVB']);
#    $ctrl->acceptable_values('AUTO_ENCRYPT_CCF', 'mpeg2TSEncryptLevel', ['RAW', 'Transport']);
#
#    # and validate
#    my $report = $ctrl->validate($cfg);
#
#    # And to add a user callback
#
#    # ------------------------------------------------------------------------
#    # method: check_scwOffsetType
#    #
#    # Example of user callback. Check a parameter value depending on another
#    # parameter.
#    #
#    # Parameters:
#    #   $cfg - The configuration, so you can access to the value of any parameter
#    #   $ctrl - The configuration controler to report errors.
#    #   $sect - the name of the section
#    #   $var - the name of the variable
#    #   $value - the value of the variable
#    #
#    # Return: TRUE when the check is OK
#    # ------------------------------------------------------------------------
#    sub check_scwOffsetType {
#        my ($cfg, $ctrl, $sect, $var, $value) = @_;
#
#        return TRUE if ($value eq 'byte' && ($cfg->value('AUTO_ENCRYPT_CCF', 'mpeg2TSEncryptLevel') eq 'RAW'));
#        return TRUE if ($value eq 'sec' && ($cfg->value('AUTO_ENCRYPT_CCF', 'mpeg2TSEncryptLevel') eq 'Transport'));
#        return FALSE;
#    }
#
#    # Attach the callback
#    $ctrl->attachCallback ('GENERAL', 'scwOffsetType',
#        ">>> Invalid offset type with the encryption level", \&check_scwOffsetType);
#
# (end)
#
# ------------------------------------------------------------------------
package ConfigControler;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use Exporter;
use Log::Log4perl;
use Data::Dumper;
use Aconfig;

use constant TRUE  => 1;
use constant FALSE => 0;

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

    $Self->{'errorNumber'} = 0;

    my %attr = @_;

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }
}

# ------------------------------------------------------------------------
# method: mandatory_sections
#
# Set or get the mandatory section list for a configuration.
#
# Parameters:
#   $listref - reference to the mandatory section list or undef
# Return: the reference to the list
# ------------------------------------------------------------------------
sub mandatory_sections {
    my $Self = shift;

    $Self->{'mandatory_sections'} = shift if @_;
    return $Self->{'mandatory_sections'};
}

# ------------------------------------------------------------------------
# method: add_mandatory_sections
#
# For convenience, it is possible to add new mandatory sections.
#
# Parameters:
#   $listref - reference to the mandatory section list or undef
# Return: the reference to the list
# ------------------------------------------------------------------------
sub add_mandatory_sections {
    my ( $Self, $listref ) = @_;

    push( @{ $Self->{'mandatory_sections'} }, @{$listref} );
    return $Self->{'mandatory_sections'};
}

# ------------------------------------------------------------------------
# method: acceptable_sections
#
# Set or get the acceptable section list. Acceptable section list is
# a list of section names or regular expressions that section names
# must match. A section name is acceptable when it is mandatory
# or it match one of the entry of the acceptable sections.
#
# Parameters:
#   $listref - reference to the acceptable section list or undef
# Return: the reference to the list
# ------------------------------------------------------------------------
sub acceptable_sections {
    my $Self = shift;

    $Self->{'acceptable_sections'} = shift if @_;
    return $Self->{'acceptable_sections'};
}

# ------------------------------------------------------------------------
# method: add_acceptable_sections
#
# For convenience, it is possible to add new acceptable sections.
#
# Parameters:
#   $listref - reference to the acceptable section list or undef
# Return: the reference to the list
# ------------------------------------------------------------------------
sub add_acceptable_sections {
    my ( $Self, $listref ) = @_;

    push( @{ $Self->{'acceptable_sections'} }, @{$listref} );
    return $Self->{'acceptable_sections'};
}

# ------------------------------------------------------------------------
# method: acceptable
#
# Check if a section or variable name is valid according to the
# specified rules. The configuration controler must be usable to check
# only some business point in a configuration file so it is better to
# be flexible and accept all configuration file when no rules are defined.
#
# The consequence is that sections are acceptable when:
#    - they are defined in the mandatory list
#    - or they match one acceptable list pattern
#    - or there is no acceptable list defined
#
# And variables are acceptable (per section) when:
#    - they are defined in the mandatory list
#    - or they math a pattern from the acceptable list
#    - or there is no acceptable list
#
# Parameters:
#   $section - section name
#   $variable - optional, checks the section when undef
# Return: boolean
# ------------------------------------------------------------------------
sub acceptable {
    my ( $Self, $section, $variable, $value ) = @_;

    $section = '_anonymous' if ( !defined($section) or ( $section eq "" ) );

    if ( defined($value) ) {

        # check for value
        return TRUE
          if (
            !exists( $Self->{'acceptable_values'}->{$section}->{$variable} ) );
        return TRUE
          if (
            _found(
                $value, $Self->acceptable_values( $section, $variable ),
                TRUE
            )
          );
    }
    elsif ( defined($variable) ) {

        # check for variable name
        return TRUE
          if ( _found( $variable, $Self->mandatory_variables($section) ) );
        return TRUE
          if (
            _found( $variable, $Self->acceptable_variables($section), TRUE ) );
        return TRUE
          if ( !exists( $Self->{'acceptable_variables'}->{$section} ) );
    }
    else {

        # check for section
        return TRUE if ( $section eq '_anonymous' );
        return TRUE if ( _found( $section, $Self->mandatory_sections() ) );
        return TRUE
          if ( _found( $section, $Self->acceptable_sections(), TRUE ) );
        return TRUE if ( !exists( $Self->{'acceptable_sections'} ) );
    }
    return FALSE;
}

# ------------------------------------------------------------------------
# method: mandatory_variables
#
# Set or get the mandatory variables list for a section. When a variable
# is mandatory, its section becomes inplicitely mandatory.
#
# Parameters:
#   $section - section name
#   $listref - reference to the mandatory variables list or undef
# Return: the reference to the list
# ------------------------------------------------------------------------
sub mandatory_variables {
    my ( $Self, $sect, $listref ) = @_;

    $sect = '_anonymous' if ( !defined($sect) or ( $sect eq "" ) );

    $Self->{'mandatory_variables'}->{$sect} = $listref if ($listref);
    return $Self->{'mandatory_variables'}->{$sect};
}

# ------------------------------------------------------------------------
# method: acceptable_variables
#
# Set or get the acceptable variable names list for a section
#
# Parameters:
#   $sect - section name
#   $listref - reference to the acceptable variables list or undef
# Return: the reference to the list
# ------------------------------------------------------------------------
sub acceptable_variables {
    my ( $Self, $sect, $listref ) = @_;

    $sect = '_anonymous' if ( !defined($sect) or ( $sect eq "" ) );

    $Self->{'acceptable_variables'}->{$sect} = $listref if ($listref);
    return $Self->{'acceptable_variables'}->{$sect};
}

# ------------------------------------------------------------------------
# method: add_acceptable_variables
#
# For convenience, it is possible to add new acceptable variabless.
#
# Parameters:
#   $sect - section name
#   $listref - reference to the acceptable section list or undef
# Return: the reference to the list
# ------------------------------------------------------------------------
sub add_acceptable_variables {
    my ( $Self, $sect, $listref ) = @_;

    push( @{ $Self->{'acceptable_variables'}->{$sect} }, @{$listref} );
    return $Self->{'acceptable_variables'}->{$sect};
}
# ------------------------------------------------------------------------
# method: acceptable_values
#
# Set or get the acceptable values for a variable. This method can
# be used to control enumerate values
#
# Parameters:
#   $sect - section name
#   $var - variable name
#   $listref - reference to the acceptable values list or undef
# Return: the reference to the list
# ------------------------------------------------------------------------
sub acceptable_values {
    my ( $Self, $sect, $var, $listref ) = @_;

    $sect = '_anonymous' if ( !defined($sect) or ( $sect eq "" ) );

    $Self->{'acceptable_values'}->{$sect}->{$var} = $listref if ($listref);
    return $Self->{'acceptable_values'}->{$sect}->{$var};
}

# ------------------------------------------------------------------------
# method: maxNumberOf
#
# Accessor to the maximum number of occurences. This method can be used to
# control than a section or a variable is not defined more than once.
#
# Parameters:
#   $sect - section name
#   $var - variable name
#   $max - the maximum number, use 1 to control unicity, 0 to make a variable illegal
#
# Return: the maximum number when defined, else -1
# ------------------------------------------------------------------------
sub maxNumberOf {
    my ( $Self, $sect, $var, $max ) = @_;

    $sect = '_anonymous' if ( !defined($sect) or ( $sect eq "" ) );

    my $key = "\[$sect\]$var";
    if (defined($max)) {
        $Self->{'maxNumberOf'}->{$key} = $max;
        return $max;
    }
    if ( exists( $Self->{'maxNumberOf'}->{$key} ) ) {
        return $Self->{'maxNumberOf'}->{$key};
    }
    else {
        return -1;
    }
}

# ------------------------------------------------------------------------
# method: errorReport
#
# Accessor to error report. To clear it, use an empty string as
# parameter. (I could even force it ?)
# ------------------------------------------------------------------------
sub errorReport {
    my $Self = shift;

    $Self->{'errorReport'} = shift if @_;
    return $Self->{'errorReport'};
}

# ------------------------------------------------------------------------
# method: addError
#
# Report an error about a section or variable. This method is used to
# centralize error reporting and get an standardized format.
#
# Parameters:
# msg - error message.
# section - section name, (undef, or _anonymous for the anonymous section)
# variable - variable name
# ------------------------------------------------------------------------
sub addError {
    my ( $Self, $msg, $sect, $var, $value ) = @_;

    my $filename   = $Self->{'config'}->{'filename'};
    my $linenumber = $Self->{'config'}->lineNumber( $sect, $var );

    if (ref($linenumber) eq 'ARRAY') {
        $linenumber = join(', ', @{$linenumber});
        
    }
    $Self->{'errorReport'} .= "$filename:$linenumber \[$sect\]$var - $msg\n";
    $Self->{'errorNumber'}++;
}

# ------------------------------------------------------------------------
# method: addNError
#
# Add several errors to the report. The error description is a string EOL
# seperated with one line per error.
#
# Parameters:
# nb - nb of new errors
# $errorDescription - string containing the error description
# ------------------------------------------------------------------------
sub addNError {
    my ( $Self, $nb, $errorDescription ) = @_;

    $Self->{'errorReport'} .= $errorDescription;
    $Self->{'errorNumber'} += $nb;
}

# ------------------------------------------------------------------------
# method: attachCallback
#
# add a user callback to a section or a variable The callback will be called
# if the specified variable is found in the configuration file. The callback
# must return TRUE in case of success.
#
#   The user callback is invoked with several parameters.
#   - The configuration, so you can access to the value of any parameter
#   - The configuration controler to report errors.
#   - the name of the section
#   - the name of the variable
#   - the value of the variable
#
# Parameters:
#   $sect - section name
#   $var - variable name
#   $comment - This string will be used in the report if the control fails
#   $callback - routine reference
# ------------------------------------------------------------------------
sub attachCallback {
    my ( $Self, $sect, $var, $comment, $callback ) = @_;

    $sect = '_anonymous' if ( !defined($sect) or ( $sect eq "" ) );

    $Self->{'callback'}->{$sect}->{$var}         = $callback;
    $Self->{'callback_comment'}->{$sect}->{$var} = $comment;
}

# ------------------------------------------------------------------------
# method: validate
#
# Parameters:
#   $cfg - the configuration to validate
# 
# Return: an empty string or a string containing a description of all
# the errors found in the configuration file.
# ------------------------------------------------------------------------
sub validate {
    my ( $Self, $cfg ) = @_;

    $Self->errorReport("");    # reset error report
    $Self->{'config'} = $cfg;

    $Self->{'errorNumber'} = 0;
    # Check for missing sections
    foreach my $sect ( @{ $Self->{'mandatory_sections'} } ) {
        if ( !_found( $sect, $cfg->sections() ) ) {
            $Self->addError( "missing mandatory section", $sect );
        }
    }

    # Check for missing variables
    foreach my $sect ( keys( %{ $Self->{'mandatory_variables'} } ) ) {
        my @list = @{ $Self->{'mandatory_variables'}->{$sect} };
        foreach my $var (@list) {
            my $value = $cfg->value( $sect, $var );
            $sect = "" if ( $sect eq '_anonymous' );
            if ( !$cfg->defined( $sect, $var ) ) {
                $Self->addError( "missing mandatory variable", $sect, $var );
            }
            elsif ( !defined($value) ) {
                $Self->addError( "undefined mandatory variable", $sect, $var );
            }
        }
    }

    # Check that all section and variable names and values are acceptable
    foreach my $sect ( @{ $cfg->sections() } ) {

        if ( $Self->acceptable($sect) ) {

            # section name is acceptable

            # Check for number of occurences
            if ($Self->maxNumberOf($sect, undef) >= 0 ) {
                if ( $cfg->numberOfOccurence( $sect, undef ) > $Self->maxNumberOf($sect, undef) ) {
                    $Self->addError(
                        "too many section definitions",
                        $sect
                    );
                }
            }

            # Check variable names
            foreach my $var ( @{ $cfg->variables($sect) } ) {
                if ( $Self->acceptable( $sect, $var ) ) {

                    # Variable name is acceptable

                    # Check for number of occurences
                    if ($Self->maxNumberOf($sect, $var) >= 0 ) {
                        if ( $cfg->numberOfOccurence( $sect, $var ) > $Self->maxNumberOf($sect, $var) ) {
                            $Self->addError(
                                "too many variable definitions",
                                $sect, $var
                            );
                        }
                    }

          # check for value
          # print "variables name is acceptable \[$sect\]$var checking value\n";
                    my $value = $cfg->value( $sect, $var );
                    if ( $Self->acceptable( $sect, $var, $value ) ) {

                        # The value is acceptable check the user callback
                        if ( exists( $Self->{'callback'}->{$sect}->{$var} ) ) {
                            my $callback = $Self->{'callback'}->{$sect}->{$var};
                            unless (
                                &$callback( $cfg, $Self, $sect, $var, $value ) )
                            {
                                my $msg =
                                  $Self->{'callback_comment'}->{$sect}->{$var};
                                $Self->addError( $msg, $sect, $var );
                            }
                        }

                    }
                    else {

                        # Report non acceptable value
                        my @list =
                          @{ $Self->{'acceptable_values'}->{$sect}->{$var} };
                        my $msg =
                          "incorrect value \"$value\" should be \["
                          . join( ", ", @list ) . "\]";
                        $Self->addError( $msg, $sect, $var );
                    }
                }
                else {
                    $Self->addError( "incorrect variable name", $sect, $var );
                }
            }
        }
        else {
            $Self->addError( "incorrect section name", $sect );
        }

    }
    return $Self->errorReport();
}

# ------------------------------------------------------------------------
# method: errorNumber
#
# Return: the number of errors found during the latest validation. 0 when
# no error has been found.
# ------------------------------------------------------------------------
sub errorNumber {
    my ( $Self, $cfg ) = @_;

    return $Self->{'errorNumber'};
}

# ------------------------------------------------------------------------
# method: _found (private)
#
# Search for an element inside a list
#
# Parameters:
#   $pattern - pattern to look for
#   $listref - reference to the list
#   $useregexp - boolean, when true use a regular expression
# Return: true when found, false when not found
# ------------------------------------------------------------------------
sub _found {
    my ( $pattern, $listref, $useregexp ) = @_;

    my $result = 0;    # not found
    foreach my $elt ( @{$listref} ) {
        if ( ( $useregexp && ( $pattern =~ $elt ) ) || ( $pattern eq $elt ) ) {
            $result = 1;
            last;
        }
    }
    return $result;
}

# ------------------------------------------------------------------------
# method: dump
#
# print an ASCII representation of the object on STDOUT
#
# Parameters:
# prefix - string to add before each line
#
# Example:
# (start code)
# Configuration file controler, actives rules
# Mandatory sections:
#    DIRECTORIES
#    SELECTIVE_SCRAMBLING
#    ECM_MUX
#    GENERAL
#    ECF_PREPROCESSING
# Acceptable section name patterns:
#    BOOKMARK_PARSING
#    TIMELINE
#    AUTOMATIC_MODES_ACTIVATION
#    AUTO_GET_CCF
#    AUTO_ENCRYPT_CCF
#    AUTO_PUT_ECF
#    DIRECTORIES
#    ECF_PREPROCESSING
#    SEP.*
#    NODE_DISK_\d+
#    NODE_FTP_\d+
#    Tuning
#    CDTV_MODE
# Mandatory variables:
#    cfgName
#    [DIRECTORIES]cpsHome, cpsPath
#    [SELECTIVE_SCRAMBLING]enable, extension
# Acceptable variable name patterns:
#    [SELECTIVE_SCRAMBLING]delay
# Acceptable values:
#    [AUTO_ENCRYPT_CCF]mpeg2TSEncryptLevel = [RAW, Transport]
#    [AUTO_ENCRYPT_CCF]encryptAlgo = [NoENCRYPTION, AES-128/ECB, AES-128/CBC, DVB]
#    [AUTO_ENCRYPT_CCF]deleteOnSuccess = [true, false]
#    [AUTO_ENCRYPT_CCF]period = [\d+]
# (end)
# ------------------------------------------------------------------------
sub dump {
    my $Self   = shift;
    my $prefix = shift;

    print $prefix, "Configuration file controler, actives rules\n";

    print $prefix, "Mandatory sections:\n";
    foreach my $sect ( @{ $Self->mandatory_sections() } ) {
        print "$prefix", "   ", $sect, "\n";
    }

    print $prefix, "Acceptable section name patterns:\n";
    foreach my $sect ( @{ $Self->acceptable_sections() } ) {
        print "$prefix", "   ", $sect, "\n";
    }

    print $prefix, "Mandatory variables:\n";
    foreach my $sect ( keys( %{ $Self->{'mandatory_variables'} } ) ) {
        my @list = @{ $Self->{'mandatory_variables'}->{$sect} };
        print "$prefix", "   ";
        if ( $sect ne '_anonymous' ) {
            print "\[$sect\]";
        }
        print join( ", ", @list ), "\n";
    }

    print $prefix, "Acceptable variable name patterns:\n";
    foreach my $sect ( keys( %{ $Self->{'acceptable_variables'} } ) ) {
        my @list = @{ $Self->{'acceptable_variables'}->{$sect} };
        print "$prefix", "   ";
        if ( $sect ne '_anonymous' ) {
            print "\[$sect\]";
        }
        print join( ", ", @list ), "\n";
    }

    print $prefix, "Acceptable values:\n";
    foreach my $sect ( keys( %{ $Self->{'acceptable_values'} } ) ) {
        foreach my $var ( keys( %{ $Self->{'acceptable_values'}->{$sect} } ) ) {
            print "$prefix", "   ";
            if ( $sect ne '_anonymous' ) {
                print "\[$sect\]$var = \[";
            }
            else {
                print "$var = \[";
            }
            my @list = @{ $Self->{'acceptable_values'}->{$sect}->{$var} };
            print join( ", ", @list );
            print "\]\n";
        }
    }

    print $prefix, "Limit on the number of occurences:\n";
    foreach my $key ( keys( %{ $Self->{'maxNumberOf'} } ) ) {
            print "$prefix", "   $key = ", $Self->{'maxNumberOf'}->{$key}, "\n";
    }

    print $prefix, "User callbacks:\n";
    foreach my $sect ( keys( %{ $Self->{'callback_comment'} } ) ) {
        foreach my $var ( keys( %{ $Self->{'callback_comment'}->{$sect} } ) ) {
            print "$prefix", "   ";
            if ( $sect ne '_anonymous' ) {
                print "\[$sect\]$var = \"";
            }
            else {
                print "$var = \"";
            }
            print $Self->{'callback_comment'}->{$sect}->{$var};
            print "\"\n";
        }
    }

}

1;
