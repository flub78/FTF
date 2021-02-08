# ----------------------------------------------------------------------------
# Title:  Class ConfigurationFile
#
# File - ConfigurationFile.pm
# Version - 1.0
#
# Abstract:
#
# This class handles configuration files. This one;
#   - Has a simple interface to access or change values
#   - Preserves comments
#   - Allows you to generate a configuration file from scratch including comments
#   - Support scalar values and lists
#   - Keeps track of the line number for better configuration file error reporting 
#   - Can be used to edit Makefiles.
#
# This module handles files with the following syntax:
#
# (start code)
# # comments are marked by a pound sign
# # this module preserves them. (Most of the time
# # there is no support for end of line comments).
#
#  Var1 = value1     # variable definition
#
#  [section1]        # section definition
#
#  List = value1, Value2, Value3  # List definition
#
#  # Lists can also be spread on several lines with backslash markers.
#  # This feature is convenient to handle Makefiles.
#  List = firstValue \
#         secondValue \
#         lastValue
# (end)
#
# To make things simple:
#
#     - All methods to access a variable have a section
#     parameter. When this section is an an empty string
#     or undef or equal to '_anonymous', it refers to the anonymous
#     section (the section to which belong the variables before the first
#     section definition)
#
#     - Values are either scalar or list reference.
#
#     - Comments are associated to variables and sections.
#     The comment of a variable or a section contains all the lines
#     above the variable or section. There is a special comment
#     named footer for comments below the last variable or section.
#
# Checks:
#     - when you create a configuration you must declare its sections and variables with <addSection> and <addVariable>
#     - access to unknow variable or list element returns undef
#     - setting of an unknown variable raises an error, "die"
#     - loading of a configuration automatically declare all found sections and variables. Later we could support configuration files checking.
#
# Usage:
#
# (start code)
# # Create and load a configuration file
# my $cfg = new ConfigurationFile('filename' => 'test.cfg');
# 
# # access to variables
# 
# # Access to variable from a section
# my $value = $cfg->value ('SectionName', 'VariableName');
# 
# # Access to a variable before the first section
# my $value2 = $cfg->value (undef, 'cfgName');
# 
# # Change to a variable
# $cfg->value ('SectionName', 'VariableName', 'newValue');
# 
# # Save the configuration
# $cfg->save();
# (end)
#
# Todo: Change the parser to support comma inside strings
# ------------------------------------------------------------------------
package ConfigurationFile;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use Exporter;
use Log::Log4perl;
use Data::Dumper;
#use File::Remote qw(:replace);       # special :replace tag
use Carp;

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

    $Self->reset();

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    if ( defined( $Self->{'filename'} ) ) {
        $Self->load( $Self->{'filename'} );
    }
}

# ------------------------------------------------------------------------
# method: filename
#
# Return the file name of a configuration. Only defined when the configuration
# as been loaded or saved.
# ------------------------------------------------------------------------
sub filename {
    my $Self = shift; return $Self->{'filename'};
}

# ------------------------------------------------------------------------
# method: reset
#
# Remove everything in the configuration
# ------------------------------------------------------------------------
sub reset {
    my $Self = shift;

    my $log = $Self->{Logger};
    $log->info('reset');

    # Attribute initialization
    delete( $Self->{'footer'} );
    delete( $Self->{'filename'} );

    $Self->{'sections'}                  = ['_anonymous'];
    $Self->{'variables'}                 = {};
    $Self->{'values'}                    = {};
    $Self->{'comments'}                  = {};
    $Self->{'variables'}->{'_anonymous'} = [];
}

# ------------------------------------------------------------------------
# method: value
#
# This accessor can be use to set or get a variable value
#
# Parameters:
# section - section name, (undef, or _anonymous for the anonymous section)
# variable - variable name
# value - when void the method get the value. when defined, set the value.
#
# Return:
#     The variable value
#
# (start code)
# # to set a value
# $cfg->value('MySection', 'MyVariable', 'Mike');
# #
# # to get a value
# print $cfg->value('MySection', 'MyVariable');
# (end)
# ------------------------------------------------------------------------
sub value {
    my ( $Self, $section, $variable, $value ) = @_;

    my $log = $Self->{Logger};

    #$log->info("value ($section, $variable, $value)");
    my $sectName = $section;
    $section = '_anonymous' if ( !defined($section) or ( $section eq "" ) );

    if ( defined($value) ) {
        $Self->defined( $section, $variable )
          or croak "unknown variable \[$sectName\]$variable";
        $Self->{'values'}->{$section}->{$variable} = $value;
    }
    return $Self->{'values'}->{$section}->{$variable};
}

# ------------------------------------------------------------------------
# method: _pushLineNumber (private)
#
# Add a line number to a section or variable.
#
# first call - set a scalar value
# second call - replace the scalar by a reference to a list
# then - just push the value to the existing list
#
#
# Parameters:
# key - section or variable name, format \[section\]variable
# number - line number to store
#
# ------------------------------------------------------------------------
sub _pushLineNumber {
    my ($Self, $key, $number)= @_;

    if (exists($Self->{'lineNumber'}->{$key})) {
        my $ln = $Self->{'lineNumber'}->{$key};
        if (ref($ln) eq 'ARRAY') {
            # it is already an array, just push the new line number
            push( @{ $Self->{'lineNumber'}->{$key} }, $number);
        } else {
            # it was still a scalar
            $Self->{'lineNumber'}->{$key} = [$ln, $number];
        }
    } else {
        # first occurence
        $Self->{'lineNumber'}->{$key} = $number;
    }
}

# ------------------------------------------------------------------------
# method: lineNumber
#
# return the line number of a section, of variable in a configuration file
#
# Parameters:
# section - section name, (undef, or _anonymous for the anonymous section)
# variable - variable name
#
# Return:
#     integer value or undef
# ------------------------------------------------------------------------
sub lineNumber {
    my ( $Self, $section, $variable ) = @_;

    $section = '_anonymous' if ( !defined($section) or ( $section eq "" ) );

    (defined($variable)) or $variable = "";
    if (exists($Self->{'lineNumber'}->{"\[$section\]$variable"})) {
        return $Self->{'lineNumber'}->{"\[$section\]$variable"};
    } else {
        return undef;
    }
}

# ------------------------------------------------------------------------
# method: numberOfOccurence
#
# return the number of time that a section or a variable is defined in a
# configuration file. Depending on the application rule it may be an error
# or not to have a section defined several times
#
# Parameters:
# section - section name, (undef, or _anonymous for the anonymous section)
# variable - variable name
#
# Return:
#     integer value
# ------------------------------------------------------------------------
sub numberOfOccurence {
    my ( $Self, $section, $variable ) = @_;

    $section = '_anonymous' if ( !defined($section) or ( $section eq "" ) );
    (defined($variable)) or $variable = "";
    my $key = "\[$section\]$variable";
    
    if (exists($Self->{'lineNumber'}->{$key})) {
        my $ln = $Self->{'lineNumber'}->{$key};
        if (ref($ln) eq 'ARRAY') {
            # it is already an array, just push the new line number
            return scalar( @{ $Self->{'lineNumber'}->{$key} });
        } else {
            # it is still a scalar
            return 1;
        }
    } else {
        return 0;
    }
}

# ------------------------------------------------------------------------
# method: numberOfValues
#
# Returns the number of element for a value. 0 when not defined, 1 for 
# scalars and n for lists.
#
# Parameters:
# section - section name, (undef, or _anonymous for the anonymous section)
# variable - variable name
#
# Return:
#     The list element value
# ------------------------------------------------------------------------
sub numberOfValues {
    my ( $Self, $section, $variable) = @_;

    my $log = $Self->{Logger};
    $log->info("numberOfValues ($section, $variable)");
    my $sectName = $section;
    $section = '_anonymous' if ( !defined($section) or ( $section eq "" ) );

    # Check for existence
    $Self->defined( $section, $variable )
      or return 0;

    # Out of range
    if ( ref( $Self->{'values'}->{$section}->{$variable} ) eq 'ARRAY' ) {
        my $size = scalar( @{ $Self->{'values'}->{$section}->{$variable} } );
        return $size;
    } else {
        return 1;
    }
}

# ------------------------------------------------------------------------
# method: EltValue
#
# Shortcut to set or get the value of a list element
#
# Parameters:
# section - section name, (undef, or _anonymous for the anonymous section)
# variable - variable name
# index - index of the element inside the list
# value - when void the method get the value. when defined, set the value.
#
# Return:
#     The list element value
# ------------------------------------------------------------------------
sub eltValue {
    my ( $Self, $section, $variable, $index, $value ) = @_;

    my $log = $Self->{Logger};
    $log->info("eltValue ($section, " . 
        defined($variable) ? $variable : '' . ", " .
        defined($index) ? $index : '' . ", " .
        defined($value) ? $value : '' . ")");
    my $sectName = $section;
    $section = '_anonymous' if ( !defined($section) or ( $section eq "" ) );

    # Check for existence
    $Self->defined( $section, $variable )
      or croak "\[$sectName\]$variable unknown variable";

    # if it is not an array
    ( ref( $Self->{'values'}->{$section}->{$variable} ) eq 'ARRAY' )
      or croak "\[$sectName\]$variable is not an array";

    # Out of range
    my $size = scalar( @{ $Self->{'values'}->{$section}->{$variable} } );
    ( $index >= 0 )
      or ( $index < $size )
      or croak "$index out of range for \[$sectName\]$variable  "
      . scalar( @{ $Self->{'values'}->{$section}->{$variable} } );

    # set
    if ( defined($value) ) {
        @{ $Self->{'values'}->{$section}->{$variable} }[$index] = $value;
    }

    # get
    return @{ $Self->{'values'}->{$section}->{$variable} }[$index];
}

# ------------------------------------------------------------------------
# method: multiline
#
# Control if a list is multiline or not. Multiline lists are saved
# with one element per line and continuation character at the end of
# the line. Non multiline lists are comma separated lists.
#
# Parameters:
# section - section name, (undef, or _anonymous for the anonymous section)
# variable - variable name, undef to attach the comment to a section.
# value - boolean, set or reset the attribute
#
# Return:
#     The attribute value
# ------------------------------------------------------------------------
sub multiline {
    my ( $Self, $section, $variable, $value ) = @_;

    $section = '_anonymous' if ( !defined($section) or ( $section eq "" ) );

    if ( defined($value) ) {
        $Self->{'multiline'}->{$section}->{$variable} = $value;
    }
    return $Self->{'multiline'}->{$section}->{$variable};
}

# ------------------------------------------------------------------------
# method: isString
#
# Control if a variable is a string or not. In this context strings are
# variables with doubles quotes. String are written with their double
# quotes when they are written. Value returns the value inside the double quote.
#
# Parameters:
# section - section name, (undef, or _anonymous for the anonymous section)
# variable - variable name, undef to attach the comment to a section.
# value - boolean, set or reset the attribute
#
# Return:
#     The attribute value
# ------------------------------------------------------------------------
sub isString {
    my ( $Self, $section, $variable, $value ) = @_;

    $section = '_anonymous' if ( !defined($section) or ( $section eq "" ) );

    if ( defined($value) ) {
        $Self->{'string'}->{$section}->{$variable} = $value;
    }
    return $Self->{'string'}->{$section}->{$variable};
}

# ------------------------------------------------------------------------
# method: comment
#
# This accessor can be use to set or get the comment associated to a
# variable or a section. Comment are strings which can contain end of lines
# "\n". When you set a comment you must add yourself the pound sign.
#
# Parameters:
# section - section name, (undef, or _anonymous for the anonymous section)
# variable - variable name, undef to attach the comment to a section.
# value - when void the method get the comment. when defined, set the comment.
#
# Return:
#     The comment value
# ------------------------------------------------------------------------
sub comment {
    my ( $Self, $section, $variable, $value ) = @_;

    my $log = $Self->{Logger};

    $section  = '_anonymous' if ( !defined($section)  or ( $section  eq "" ) );
    $variable = '_anonymous' if ( !defined($variable) or ( $variable eq "" ) );

    if ( defined($value) ) {
        $Self->{'comments'}->{$section}->{$variable} = $value;
    }

# $log->info("comment ($section, $variable, $value) = $Self->{'comments'}->{$section}->{$variable}");
    return $Self->{'comments'}->{$section}->{$variable};
}

# ------------------------------------------------------------------------
# method: header
#
# Accessor to the first comment above the first variable or section.
#
# Parameters:
# value - when void the method get the comment. when defined, set the comment.
#
# Return:
#     The header value
# ------------------------------------------------------------------------
sub header {
    my ( $Self, $value ) = @_;

    my $log = $Self->{Logger};
    $log->info("header (" . defined($value) ? $value : "" .")");
    return $Self->comment( undef, undef, $value );
}

# ------------------------------------------------------------------------
# method: footer
#
# Accessor to the last comment below the las variable or section.
#
# Parameters:
# value - when void the method get the comment. when defined, set the comment.
#
# Return:
#     The comment value
# ------------------------------------------------------------------------
sub footer {
    my ( $Self, $value ) = @_;

    my $log = $Self->{Logger};
    $log->info("footer($value)") if ($value);

    if ( defined($value) ) {
        $Self->{'footer'} = $value;
    }
    return $Self->{'footer'};
}

# ------------------------------------------------------------------------
# method: sections
#
# Set or return the list of sections
#
# Parameters:
# listref - when set a reference to a list of sections. Use _anonymous to
# refer the the first anonymous section.
#
# Return:
#     A reference to the section list.
# ------------------------------------------------------------------------
sub sections {
    my ( $Self, $listref ) = @_;

    my $log = $Self->{Logger};

    # $log->info("sections ($listref)");
    if ( defined($listref) ) {
        $Self->{'sections'} = $listref;
    }
    return $Self->{'sections'};
}

# ------------------------------------------------------------------------
# method: addSection
#
# Create a new section. Nothing is done when the section already
# exists. So if you have the same section several times in the same
# file, they are concatened by a file read and the layout is not preserved.
#
# Parameters:
# section - section name
# lineNumber - store the line number to help navigation in the file
# ------------------------------------------------------------------------
sub addSection {
    my ( $Self, $section, $lineNumber ) = @_;

    my $log = $Self->{Logger};
    $log->info("addSection($section)");
    # add section line number
    $Self->_pushLineNumber("\[$section\]", $lineNumber);
    return if ( exists( $Self->{'variables'}->{$section} ) );
    push( @{ $Self->{'sections'} }, $section );
    $Self->{'variables'}->{$section} = [];
}

# ------------------------------------------------------------------------
# method: variables
#
# Set or return the list of variables of a section
#
# Parameters:
# section - section name, (undef, or _anonymous for the anonymous section)
# listref - when set a reference to a list of variables.
#
# Return:
#     A reference to the variable list.
# ------------------------------------------------------------------------
sub variables {
    my ( $Self, $section, $listref ) = @_;

    my $log = $Self->{Logger};

    # $log->info("variables ($section, $listref)");
    $section = '_anonymous' if ( !defined($section) or ( $section eq "" ) );
    if ( defined($listref) ) {
        $Self->{'variables'}->{$section} = $listref;
    }
    return $Self->{'variables'}->{$section};
}

# ------------------------------------------------------------------------
# method: addVariable
#
# Add a variable to a section. When it doe not exist
# creates a scalar variable. If there is scalar variable with the same name,
# replace it by a list and insert the two values.
# If it is already a list, add the value at the end of the list.
#
# The interface is a little weird, but it is quite convenient to create
# lists on the fly. You do not have to worry about scalars and lists,
# just call repeatively addVariable with all the values.
#
# When no value is specified, the variable is created empty if it did not
# exist and nothing is done in other cases.
#
# Parameters:
# section - section name, (undef, or _anonymous for the anonymous section)
# variable - variable name
# lineNumber - store the line number to help navigation in the file
# value - when defined, set the value. list allowed
# ------------------------------------------------------------------------
sub addVariable {
    my ( $Self, $section, $variable, $lineNumber, $value ) = @_;

    my $log = $Self->{Logger};

    $section = '_anonymous' if ( !defined($section) or ( $section eq "" ) );

    # the section must exist
    defined( $Self->{'variables'}->{$section} )
      or croak "unknown section $section";

    # print "addVariable \"\[$section\]$variable\"\n";
    
    # add variable line number
    $Self->_pushLineNumber("\[$section\]$variable", $lineNumber);

    if ( !defined( $Self->{'values'}->{$section}->{$variable} ) ) {

        # create a scalar variable
        push( @{ $Self->{'variables'}->{$section} }, $variable );
        if ( defined($value) ) {
            $Self->{'values'}->{$section}->{$variable} = $value;
            return $value;
        }
    }
    elsif ( ref( $Self->{'values'}->{$section}->{$variable} ) eq 'ARRAY' ) {

        # it is already an array
        if ( defined($value) ) {
            push( @{ $Self->{'values'}->{$section}->{$variable} }, $value );
            return $value;
        }
    }
    elsif ( defined($value) ) {

        # it is a scalar which must be replaced by an array
        my $initial_value = $Self->{'values'}->{$section}->{$variable};
        $Self->{'values'}->{$section}->{$variable} = [];    # create a list
        push( @{ $Self->{'values'}->{$section}->{$variable} }, $initial_value );
        push( @{ $Self->{'values'}->{$section}->{$variable} }, $value );
        return $value;
    }
}

# ------------------------------------------------------------------------
# method: defined
#
# Check if a section or variable has been defined
#
# Parameters:
# section - section name, (undef, or _anonymous for the anonymous section)
# variable - variable name
#
# Returns: boolean
# ------------------------------------------------------------------------
sub defined {
    my ( $Self, $section, $variable ) = @_;

    $section = '_anonymous' if ( !defined($section) or ( $section eq "" ) );

    if ( !defined($variable) ) {

        # check for section definition
        return defined( $Self->{'variables'}->{$section} );
    }

    # Check for variable definition
    foreach my $v ( @{ $Self->{'variables'}->{$section} } ) {
        return 1 if ( $v eq $variable );
    }
    return 0;
}

# ------------------------------------------------------------------------
# method:  load
#
# Load the configuration from a file
#
# Parameters:
# filename - name of the file
# ------------------------------------------------------------------------
sub load {
    my ( $Self, $filename ) = @_;

    my $log = $Self->{Logger};
    $log->info("load $filename");
    my $line;
    my $lineNumber     = 0;
    my $curr_sect      = undef;
    my $curr_var       = undef;
    my $comment        = undef;
    my $header_defined = 0;
    my $previous_multiline
      ;    # true when the previous line had a continuation character '\'
    my $multiline =
      0;    # true if the current line has a continuation character '\'

no strict;
    open( FD, "< $filename" ) or croak("cannot open file $filename : $!");
    while ( $line = <FD> ) {

        $lineNumber++;

        # Comment
        if ( $line =~ /^(\s*#.*)/ ) {
            $log->warn($line);
            $comment .= $1 . "\n";
            next;
        }

        if ( $line =~ /^(.*)\\\s*/ ) {

            # continuation character
            $line      = $1;
            $multiline = 1;
        }

        # Section name
        if ( $line =~ /^\s*\[(.*)\]\s*(#.*)?/ ) {
            $log->info($line);
            $curr_sect = $1;
            $Self->addSection( $curr_sect, $lineNumber );
            if ($header_defined) {
                $Self->comment( $curr_sect, undef, $comment );
            }
            else {
                $Self->header($comment);
            }
            $comment        = undef;
            $header_defined = 1;
            next;
        }

        if ($previous_multiline) {
            $line =~ /^\s*(.*)\s*/;
            $Self->addVariable( $curr_sect, $curr_var, $lineNumber, $1 );
            $previous_multiline = $multiline;
            $multiline          = 0;
            next;
        }

        # Variable setting
        if ( $line =~ /^\s*([\/\-\.\s\w]*)\s*=\s*(.*)(\\)?/ ) {
            $log->error($line);
            $curr_var = $1;
            my $values = $2;
            # remove leading and trailing spaces
            $curr_var =~ s/^\s+//;
            $curr_var =~ s/\s+$//;
            # print "\"\[$curr_sect\]$curr_var\" = $values\n";
            
            my @splitted = split( /\s*,\s*/, $values );
            foreach my $v (@splitted) {
                if ( $v =~ /^\"(.*)\"/ ) {
                    $Self->isString( $curr_sect, $curr_var, 1 );
                    $Self->addVariable( $curr_sect, $curr_var, $lineNumber,
                        $1 );
                }
                else {
                    $Self->addVariable( $curr_sect, $curr_var, $lineNumber,
                        $v );
                }
            }
            if ($header_defined) {
                $Self->comment( $curr_sect, $curr_var, $comment );
            }
            else {
                $Self->header($comment);
            }
            $comment        = undef;
            $header_defined = 1;
            $Self->multiline( 'NewSection', 'var1', 1 ) if ($multiline);
            $previous_multiline = $multiline;
            $multiline          = 0;
            next;
        }

        # Everything else is considered as comment
        $comment .= $line;
        $log->warn($line);
    }
    $Self->footer($comment);
    close (FD);
    $Self->{'filename'} = $filename;
    use strict;
}

# ------------------------------------------------------------------------
# method: _write (private)
#
# print an ASCII representation of the object
#
# Parameters:
# prefix - string to add before each line
# ------------------------------------------------------------------------
sub _write {
    my ( $Self, $fd, $prefix ) = @_;

    my $comment = undef;

    $prefix = "" if ( !defined($prefix) );

    # for all sections
    foreach my $sect ( @{ $Self->sections() } ) {

        # print comment
        $comment = $Self->comment( $sect, undef );
        print $fd $comment if defined($comment);

        # print section into square brackets
        print $fd $prefix . "\[$sect\]\n" if ( $sect ne '_anonymous' );

        # for all variables
        foreach my $var ( @{ $Self->variables($sect) } ) {
            my $value = $Self->value( $sect, $var );

            # print comment
            $comment = $Self->comment( $sect, $var );
            print $fd $comment if defined($comment);

            print $fd $prefix . "$var = ";
            if ( !defined($value) ) {
                print $fd "\n";
                next;
            }

            if ( ref($value) eq 'ARRAY' ) {

                my @quotedValues = @{$value};
                if ( $Self->isString( $sect, $var ) ) {
                    my $i = 0;
                    foreach my $v (@quotedValues) {
                        $quotedValues[$i] = "\"$v\"";
                        $i++;
                    }
                }

                # print list
                if ( $Self->multiline( $sect, $var ) ) {
                    print $fd
                      join ( " \\\n" . $prefix . "    ", @quotedValues );
                }
                else {
                    print $fd join ( ', ', @quotedValues );
                }
            }
            else {

                # print scalar
                if ( $Self->isString( $sect, $var ) ) {
                    $value = "\"$value\"";
                }
                print $fd $value;
            }
            print $fd "\n";
        }
    }
    $comment = $Self->footer();
    print $fd $comment if defined($comment);
}

# ------------------------------------------------------------------------
# method: dump
#
# print an ASCII representation of the object on STDOUT
#
# Parameters:
# prefix - string to add before each line
# ------------------------------------------------------------------------
sub dump {
    my $Self   = shift;
    my $prefix = shift;

    $Self->_write( *STDOUT, $prefix );
}

# ------------------------------------------------------------------------
# method: save
#
# Save the configuration into a file.
#
# Parameters:
# filename - name of the file, default = the one set by load.
# ------------------------------------------------------------------------
sub save {
    my ( $Self, $filename ) = @_;

    my $log = $Self->{'Logger'};
    $log->info("save $filename") if ($filename);

    defined($filename) or $filename = $Self->{'filename'};

no strict;
    $Self->{'filename'} = $filename;
    open( FD, "> $filename" ) || croak("can't open $filename: $!");
    $Self->_write(*FD);
    close(FD);
use strict;
}

# ------------------------------------------------------------------------
# method: check
#
# Global check of a set of values.
#
# Parameters:
# values - hash of the values. {'section'}->{'name'}-{'value'}
#
# Returns:
# an empty string when all the values match, else the differences description
# ------------------------------------------------------------------------
sub check {
    my $Self   = shift;
    my %values = @_;

    my $result = "";
    foreach my $sect ( keys(%values) ) {
        foreach my $var ( keys( %{ $values{$sect} } ) ) {
            my $value = $values{$sect}->{$var};
            if ( !defined($value) ) {
                $result .= "\[$sect\]$var not defined";
                next;
            }
            if ( ref($value) eq 'ARRAY' ) {
                ( ref( $Self->{'values'}->{$sect}->{$var} ) eq 'ARRAY' )
                  or croak "\[$sect\]$var is not a list";
                my $size = scalar( @{$value} );
                my $obj_size = scalar( @{ $Self->value( $sect, $var ) } );
                ( $size == $obj_size )
                  or croak "\[$sect\]$var size => $size != $obj_size";
                my $i = 0;
                foreach my $v ( @{$value} ) {
                    unless ( $v == $Self->eltValue( $sect, $var, $i ) ) {
                        $result .=
                          "\[$sect\]$var\[$i\] => $v != "
                          . $Self->eltValue( $sect, $var, $i ) . "\n";
                    }
                    $i++;
                }

            }
            else {
                unless ( $value eq $Self->value( $sect, $var ) ) {
                    $result .=
                      "\[$sect\]$var => $value != "
                      . $Self->value( $sect, $var ) . "\n";
                }
            }
        }
    }
    return $result;
}

# ------------------------------------------------------------------------
# method: set
#
# Global setting of a set of values.
#
# Parameters:
# values - hash of the values. {'section'}->{'name'}-{'value'}
# ------------------------------------------------------------------------
sub set {
    my $Self   = shift;
    my %values = @_;

    foreach my $sect ( keys(%values) ) {
        foreach my $var ( keys( %{ $values{$sect} } ) ) {
            if ( !$Self->defined( $sect, $var ) ) {
                $Self->addVariable( $sect, $var, undef,
                    $values{$sect}->{$var} );
            }
            else {
                $Self->value( $sect, $var, $values{$sect}->{$var} );
            }
        }
    }
}

1;
