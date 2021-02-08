use lib "$ENV{'FTF'}/lib";
use Protocol::Utilities;

# Functional style

  use Digest::CRC qw(crc32 crc16 crcccitt crc crc8);
  $crc = crc32("123456789");
  print "crc = $crc\n";
  
  $crc = crc16("123456789");
  $crc = crcccitt("123456789");
  $crc = crc8("123456789");

#  $crc = crc($input,$width,$init,$xorout,$refout,$poly,$refin);
#
#  # OO style
#  use Digest::CRC;
#
#  $ctx = Digest::CRC->new(type=>"crc16");
#  $ctx = Digest::CRC->new(width=>16, init=>0x2345, xorout=>0x0000, 
#                          poly=>0x8005, refin=>1, refout=>1, cont=>1);
#
#  $ctx->add($data);
#  $ctx->addfile(*FILE);
#
#  $digest = $ctx->digest;
#  $digest = $ctx->hexdigest;
#  $digest = $ctx->b64digest;

     
    
    