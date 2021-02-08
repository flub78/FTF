# ----------------------------------------------------------------------------
#
# Title: Class Events::UDPReader
#
# File - Events/UDPReader.pm
# Author - frederic
#
# Name:
#
#    package Events::UDPReader
#
# Abstract:
#
#    UDPReader connector.
#
# ----------------------------------------------------------------------------
package Events::UDPReader;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Log::Log4perl;
use Data::Dumper;
use Events::Connector;

$VERSION = 1;

@ISA = qw(Events::Connector);


# ------------------------------------------------------------------------
# method: _init (private)
#
# Initialisation of the object. Do not call directly.
# ------------------------------------------------------------------------
sub _init {
    my $Self = shift; 

    $Self->Events::Connector::_init(@_);

    my %attr = @_;

    # Takes the constructor parameters as object attributs
    foreach my $key ( keys %attr ) {
        $Self->{$key} = $attr{$key};
    }

    # Others initialisation
    exists($Self->{port}) or die "undefined port";

    $Self->trace("UDP listener on port $Self->{'port'}");
    $Self->{'id'} = "UDP:" . $Self->{'port'};
    
    $Self->{socket} = new IO::Socket::INET(
            LocalPort => $Self->{port},
            Proto     => 'udp');
    die "Could not connect: $!" unless $Self->{socket};   
    Events::EventsManager::registerHandler($Self, $Self->{socket}, 'read');    
}

1;
