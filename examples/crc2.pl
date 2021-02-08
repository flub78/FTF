# Functional style
use lib "$ENV{'FTF'}/lib";
use Protocol::Utilities;

use String::CRC32 qw(crc);
    
    ($crc_low, $crc_high) = crc("some string", 64);
    $crc_binary = crc("some string", 64);
    ($crc_low, $crc_high) = unpack("LL", $crc_binary);
    my $crc_small = crc("123456789", 32);
    
    print "crc =" . bin2hexa($crc_small) . "\n";
    
    
    