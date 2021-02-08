# ------------------------------------------------------------------------
# Title: XML Generation
#
# Source - <file:../xml_gen.pl.html>
#
# Abstract:
#
#    Small example of XML generation. I prefer XML::Writer
#    to XML::Generator because you can generate the output on the fly
#    with the startTag and endTag method. It is often more convenient
#    than to create the whole XML tree first.
#
# Usage:
# (Start code)
# perl xml_gen.pl; cat output.xml
# (end)
#
# Example:
#   (Start code)
#
#use XML::Writer;
#use IO::File;
#
#my $output = new IO::File(">output.xml");
#
#my $writer = new XML::Writer( OUTPUT => $output );
#$writer->startTag( "greeting", "class" => "simple" );
#$writer->characters("Hello, world!");
#$writer->endTag("greeting");
#$writer->end();
#   (end)
# ------------------------------------------------------------------------
use XML::Writer;
use IO::File;

my $output = new IO::File(">output.xml");

my $writer = new XML::Writer( OUTPUT => $output );
$writer->startTag( "greeting", "class" => "simple" );
$writer->characters("Hello, world!");
$writer->endTag("greeting");
$writer->end();
$output->close();
