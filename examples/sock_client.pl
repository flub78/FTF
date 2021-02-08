use IO::Socket;
my $sock = new IO::Socket::INET(
    PeerAddr => 'localhost',
    PeerPort => '3456',
    Proto    => 'tcp',
);
die "Could not create socket: $!\n" unless $sock;
print $sock "Hello there!\n";

while( <$sock>) {
    print "<- " . $_ . "\n";
} 

close($sock);
