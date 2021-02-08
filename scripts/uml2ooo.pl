# ------------------------------------------------------------------------
# Title:  UML2OOO BoUML to Open Office
#
# File - scripts/uml2ooo.pl
# Version - 1.0
#
# Abstract:
#
#    Generate a Open Office Design Document from an HTML document
#    generated by BoUML.
# ------------------------------------------------------------------------
package Uml2OOO;

use strict;
use lib "$ENV{'PERL_TEST_TOOLS_PATH'}/lib";
use lib "$ENV{'PERL_TEST_TOOLS_PATH'}/lib/site_perl";
use TestTools::Script;
use TestTools::Parser::Aconfig;
use TestTools::Doc::DocGen;
use File::Basename qw(fileparse);
use HTML::PullParser ();
use Data::Dumper;
use TestTools::Conf::ScriptConfig;

# use OpenOffice::OODoc;

use vars qw($VERSION @ISA @EXPORT);
use Exporter;

$VERSION = 1;
@ISA     = qw(TestTools::Script);

# This hash table is used to declare and define options.
my %OptionSet = (
    template => {
        type        => "string",
        description => "template document to complete",
        default     => "nagra.ott"
    },
    uml => {
        type        => "string",
        description => "uml document in html",
        default     => ""
    },
    output => {
        type        => "string",
        description => "result document",
        default     => ""
    },
);

my $footer = '
Examples:

perl $PTT/scripts/uml2ooo.pl -uml html/index.html -output protocol.oot -template $PTT/templates/pdd.oot
';

# ------------------------------------------------------------------------
# method: heading
# ------------------------------------------------------------------------
sub heading {
    my ($Self, $level, $title) = @_;
    
    # Remove the numbers
    if ($title =~ /\d*(\.\d*)*\s*(.*)/) {
        $title = $2;
    }
    print "treating heading $level $title\n";
    my $res;
    if ($level == 1) {    
        $res = $Self->{'doc'}->appendHeading(1, $title);
    } elsif ($level == 2) {
        $res = $Self->{'doc'}->appendHeading(2, $title);
    } elsif ($level == 3) {
        $res = $Self->{'doc'}->appendHeading(3, $title);
    } elsif ($level == 4) {
        $res = $Self->{'doc'}->appendHeading(4, $title);
    }
    if ( $res->isHeading() ) {
        print "heading: ", $res->getName(), "\n";
    }
}

# ------------------------------------------------------------------------
# method: paragraph
# ------------------------------------------------------------------------
sub paragraph {
    my ($Self, $txt) = @_;
    
    print "treating paragraph $txt\n";
    $Self->{'doc'}->appendParagraph(text => $txt);        
}

# ------------------------------------------------------------------------
# method: title
# ------------------------------------------------------------------------
sub title {
    my ($Self, $title) = @_;
    
    print "treating title $title\n";
    $Self->{'doc'}->title($title);    
}

# ------------------------------------------------------------------------
# method: diagram
# ------------------------------------------------------------------------
sub diagram {
    my ($Self, $img) = @_;
    
    print "treating diagram $img\n";
    $Self->{'doc'}->appendImage($img, "Unknown Title");    
}

# ------------------------------------------------------------------------
# routine: run
#
#  Scrip main method.
# ------------------------------------------------------------------------
sub run {
    my $Self = shift;

    # fetch and check CLI parameters
    my $uml      = TestTools::Conf::ScriptConfig::GetOption('uml');
    my $output   = TestTools::Conf::ScriptConfig::GetOption('output');
    my $template = TestTools::Conf::ScriptConfig::GetOption('template');

    die "Missing uml filename\n"      unless $uml;
    die "Missing template filename\n" unless $template;
    die "Missing output filename\n"   unless $output;

    my ( $base, $dir, $ext ) = fileparse($uml);

    # Create an OpenOffice document
    my $doc = new TestTools::Doc::DocGen(
        'template' => $template,
        'output' => $output
    );
    $Self->{'doc'} = $doc;
    
    # change dir to the html file to interpret the relative paths
    my $pwd = `pwd`;
    chomp ($pwd);
    chdir $dir || die "cannot cd to $dir";
    print "cd $dir\n";
    print "uml = $uml, base=$base, ext= $ext\n";

    # Create an XML parser
    my $p = HTML::PullParser->new(
        file            => $base,
        start           => 'event, tagname, @attr',
        end             => 'event, tagname',
        text            => 'event, dtext',
        ignore_elements => [qw(script style)],
    ) || die "Can't open: $!";
    
    # Set some meta data
#    $doc->subject('Preliminary Detail Design');
#    $doc->description(
#        'This document contains the detailled description of the 
#software documentation generation module design.'
#    );
#    $doc->keywords( 'Perl', 'Documentation', 'Generation' );
    
    
    my $txt;
    my $current;
    my $level = 0;
    while ( my $token = $p->get_token ) {

        #...do something with $token
        my @list = @{$token};
        
        if ($list[0] eq 'start') {
            print '  ' x $level, "<<< ", join(", ", @list), "\n";
            $level++;
            my $what = $list[1];
            if ($what eq 'img') {
                $Self->diagram ($list[3]);
            }   
              
        } elsif ($list[0] eq 'end') {
            $level--;
            print '  ' x $level, ">>> ", join(", ", @list), "\n";
            
            my $what = $list[1];
            if ($what eq 'title') {
                $Self->title($txt);
                                
            } elsif ($what eq 'h1') {
                $Self->heading(1, $txt);
                                
            } elsif ($what eq 'h2') {
                $Self->heading(2, $txt);
                                
            } elsif ($what eq 'h3') {
                $Self->heading(3, $txt);
                                
            } elsif ($what eq 'h4') {
                $Self->heading(4, $txt);

            } elsif ($what eq 'p') {
                $Self->paragraph($txt);
                                
            } else {
                # print ">>>>>>>>>>>> end = ", $what, " ", $txt, "\n";
            }
            $txt = "";  

        } elsif ($list[0] eq 'text') {
            my $para = $list[1];
            chomp($para);
            $txt .= $para;
            # print "\"" . $para . "\"\n";  

        } else {
            # print join(", ", @list), "\n";
        }
    }

    # Close and save
    $doc->appendParagraph( text => "" );
    $doc->appendParagraph( style => 'Centre', text => "- End of document -" );
    
    # return to working dir
    # chdir $pwd || die "cannot cd to $pwd";
    print "pwd = $pwd\n";
    my $fileToSave = $pwd . "/" . $output;
    $doc->save($output);
    
    print "$output generated\n";
}

# ------------------------------------------------------------------------
my @argv = @ARGV;
Initialize( TestTools::Script::configurationFilename(),
    \%OptionSet, TestTools::Script::optionSet() );
my $script = new Uml2OOO(footer     => $footer);
$script->run();

