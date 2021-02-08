# ----------------------------------------------------------------------------
#
# Title:  Class TLV_Alternative
#
# File - Protocol/TLV_Alternative.pm
# Version - 1.0
#
# Name:
#
#       package Protocol::TLV_Alternative
#
# Abstract:
#
#       TLV Alternatives are objects used to decode TLV messages when
#       you rely on the tag to determine the type of the element
#       that you are reading. There is no encode method for 
#       alternatives as you are supposed to know the type of what
#       you are encoding.
# ------------------------------------------------------------------------
package Protocol::TLV_Alternative;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $BYTES);

use Exporter;
use Log::Log4perl;
use Data::Dumper;

use lib "$ENV{'FTF'}/lib";
use Protocol::Utilities;
use Protocol::Type;
use Message;
use Carp;

$VERSION = 1;

@ISA = qw(Protocol::Type);

# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift;

    # Call the parent initialization first
    $Self->Protocol::Type::_init(@_);

    croak $Self->{'Class'} . ": Undefined choices attribute in TLV alternative declaration"
      unless ( exists( $Self->{'choices'} ) );

    foreach my $choice (@{$Self->{'choices'}}) {
        croak "unknown type \"$choice\" in alternative declaration" unless (DefinedType($choice));
        my $type = TypeFromName($choice);
        my $tag = $type->tag();
        
        croak $Self->{'Class'} . ": duplicated tag=$tag" if (exists($Self->{'type_by_tag'}->{$tag}));
        $Self->{'type_by_tag'}->{$tag} = $choice;
        
        # check that all the choices have the same tag type
        if (exists($Self->{'tag_type'})) {
            croak $Self->{'Class'} . ": tag type \"" . $Self->{'tag_type'} . 
                "\" does not match $choice tag type \"" . $type->tag_type() . "\"" unless($Self->{'tag_type'} eq $type->tag_type());
               
        } else {
            $Self->{'tag_type'} = $type->tag_type();
        }
        
        # check that all the choices have the same length type
        if (exists($Self->{'length_type'})) {
            croak $Self->{'Class'} . ": length type \"" . $Self->{'length_type'} . 
                "\" does not match $choice length type \"" . $type->length_type() . "\"" unless($Self->{'length_type'} eq $type->length_type());
               
        } else {
            $Self->{'length_type'} = $type->length_type();
        }
    }
    # print "alternative = " . Dumper ($Self) . "\n";
}


# ------------------------------------------------------------------------
# method: decode
#
# Decode a binary buffer and return a record message. The main difference
# with regular record decode, is that fields name are predefined and
# the buffer is truncated according LENGTH
# ------------------------------------------------------------------------
sub decode {
    my ( $Self, $bin ) = @_;

    $Self->{Logger}->warn("TLV_Alternative::decode(\"" . bin2hexa($bin) . "\")");
    my $msg = new Message(
        value  => {},
        errors => 0,
        type   => $Self->{'name'},
        size   => 0
    );

    my $elt_type_name = $Self->{'choices'}[0];
    my $elt_type = TypeFromName($elt_type_name);
    my $tag = $elt_type->decode_tag($bin);
    
    unless (defined($tag)) {
         $msg->add_error("no tag found while decoding a " . $Self->{'name'}); 
        return $msg;        
    }
    
    unless (exists($Self->{'type_by_tag'}->{$tag})) {
        $msg->add_error("unknown tag $tag while decoding a " . $Self->{'name'}); 
        return $msg; 
    }
    
    $Self->{Logger}->warn("TLV_Alternative::found: tag=" . $tag . 
        ", type=" . $Self->{'type_by_tag'}->{$tag});        
    return Decode ($Self->{'type_by_tag'}->{$tag}, $bin);
}

1;
