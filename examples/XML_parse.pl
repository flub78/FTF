#!/usr/local/bin/perl -w

# ------------------------------------------------------------------------
# Title: XML parsing
#
# Source - <file:../XML_parse.pl.html>
# Version - 1.0
#
# Abstract:
#
#    Extract and dump the class diagram data
#    of a dia file (Protocol.xml). Dia is a graphical editor with UML
#    support.
#
#    It is also an example of an XML file analysis using XML::Twig.
#
# Usage:
# (Start code)
# perl XML_parse.pl example.xml
# (end)
# ------------------------------------------------------------------------
package XML_extract;

use strict;
use lib "$ENV{'FTF'}/lib";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Script;

$VERSION = 1;
@ISA     = qw(Script);

use Data::Dumper;
use ExecutionContext;
# use ScriptConfiguration;

use XML::Twig;

# ########################################################################
my $twig = XML::Twig->new();

# inheritance relationship
my %parents = ();
my %names   = ();

# ------------------------------------------------------------------------
# routine: removePounds
# remove the leading and trailing pound signs from dia identifiers
# ------------------------------------------------------------------------
sub removePounds {
    my $str = shift;

    if ( $str =~ /^#(.*)#$/ ) {
        return $1;
    }
    else {
        return $str;
    }
}

# ------------------------------------------------------------------------
# routine: diaAttribute
# extracts and returns class attributes, for some reason dia does not
# store class attributes in XML attributes but rather in sub-elements.
#
# Parameters:
#    class - class XML element
#    attName - Attribute name
# ------------------------------------------------------------------------
sub diaAttribute {
    my $elt  = shift;
    my $name = shift;

    my $dia_elt = $elt->first_child("dia:attribute\[\@name=\"$name\"\]");
    return removePounds( $dia_elt->first_child()->text() );
}

# ------------------------------------------------------------------------
# routine: extractInheritance
#
# Extract inheritance related data
#
# Parameter:
#     parent - XML classes parent element
# ------------------------------------------------------------------------
sub extractInheritance {

    my $dia_layer = shift;

    # for all the classes get the dia objects list
    my @subs = $dia_layer->children('dia:object[@type="UML - Generalization"]');

    foreach my $elt (@subs) {

        my $dia_con = $elt->first_child('dia:connections');

        my $parent = $dia_con->first_child('dia:connection[@handle="0"]');
        my $to     = $parent->att('to');

        my $child = $dia_con->first_child('dia:connection[@handle="1"]');
        my $from  = $child->att('to');

        $parents{$from} = $to;
    }
}

# ------------------------------------------------------------------------
# routine: extractClasses
#
# Extract data from classes
#
# Parameter:
#     parent - XML classes parent element
# ------------------------------------------------------------------------
sub extractClasses {

    my $dia_layer = shift;

    # for all the classes get the dia objects list
    my @subs = $dia_layer->children('dia:object[@type="UML - Class"]');
    foreach my $elt (@subs) {

        # elt is a dia:object

        # Class comment
        my $comment = diaAttribute( $elt, 'comment' );
        if ($comment) {
            print("# $comment\n");
        }

        # Class name
        my $class = diaAttribute( $elt, 'name' );

        # id attribute
        my $id = $elt->att('id');
        $names{$id} = $class;

        # Rebuild the full name
        my $parentId = $id;
        my $fullName = $class;
        while ( $parentId = $parents{$parentId} ) {
            $fullName = $names{$parentId} . '::' . $fullName;
        }

        print( "class " . $fullName . " {\n" );

        # Class attributes
        my @attributes = $elt->get_xpath(qq{dia:attribute[\@name="attributes"]/dia:composite[\@type="umlattribute"]});
        foreach my $att (@attributes)
        {
            print "\t" . diaAttribute( $att, 'type' ) . " ";
            print diaAttribute( $att, 'name' ) . ";";

            my $comment = diaAttribute( $att, 'comment' );
            if ($comment) {
                print("\t\t# $comment");
            }
            print "\n";
        }

        # Class methods
        my @operations = $elt->get_xpath(qq{dia:attribute[\@name="operations"]/dia:composite[\@type="umloperation"]});
        foreach my $op (@operations) 
        {
            my $comment = diaAttribute( $op, 'comment' );
            if ($comment) {
                print("\t# $comment\n");
            }
            print "\t" . diaAttribute( $op, 'type' );
            print " " . diaAttribute( $op,  'name' ) . "(";

            # Method parameters
            my @param_list = $op->get_xpath(qq{dia:attribute[\@name="parameters"]/dia:composite[\@type="umlparameter"]});  
            foreach my $param (@param_list) {
                print diaAttribute( $param, 'type' ) . " ";
                print diaAttribute( $param, 'name' );
                print ", ";
            }
            print ");\n";
        }
        print "}\n\n";
    }
}

# ------------------------------------------------------------------------
# routine: parse
#
# Parse an XML uncompressed dia file.
#
# Parameters:
#     filename : name of the file to parse
# ------------------------------------------------------------------------
sub parse {

    my $filename = shift;

    $twig->parsefile($filename);
    my $root = $twig->root;

    my $dia_layer = $root->first_child('dia:layer');

    print '# ' . '-' x 76 . "\n";
    print '# ' . '-' x 76 . "\n";

    extractInheritance($dia_layer);
    extractClasses($dia_layer);

    # $twig->print();
}

# ------------------------------------------------------------------------
# routine: run
#
#  Scrip main method.
# ------------------------------------------------------------------------
sub run {
    my $Self = shift;

    my $name = ExecutionContext::basename();
    $Self->info("starting $name");

    if (!@ARGV) {
        parse ('Protocol.xml');
        exit;
    }
    # for all the files specified on CLI
    foreach my $arg (@ARGV) {
        while ( glob($arg) ) {
            if ( -f $_ ) {
                $Self->info( "file: " . $_ );
                parse($_);
            }
            if ( -d $_ ) { $Self->info( "directory: " . $_ ) }
        }
    }
    $Self->info("$name is completed");
}

# ------------------------------------------------------------------------    
my $script = new XML_extract();
$script->run();

