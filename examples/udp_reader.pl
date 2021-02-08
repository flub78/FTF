# ------------------------------------------------------------------------
# Title:  Minimal UDP reader Example
#
# File - <file: ../udp_reader.pl.html>
# Version - 1.0
#
# Abstract:
# 
#   Small UDP reader
# ------------------------------------------------------------------------
use IO::Socket;

my $port = 12345;

my $server = IO::Socket::INET->new(LocalPort => $port,
                                   Proto => 'udp') 
    or die "socket: $@";     # yes, it uses $@ here

my $MAXLEN = 4096;
my $datagram;
my $i = 0; 
my $flags = 0;

while (my $him = $server->recv($datagram, $MAXLEN, $flags)) {
    # do something
    print "$i: $datagram\n";
    # print $datagram;
    $i++;
}

