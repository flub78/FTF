# ------------------------------------------------------------------------
# Title:  Cryptography example
#
# Source - <file:../script.pl.html>
#
# Abstract:
#
#    This is a script template. It derives from the <Script> class, look
#    to the script class documentation for details.
#
#    This example parse directories and files to count the number of
#    occurence of a given pattern.
#
#    Place to customize are identified by a "To customize: comment"
#
# API Example:
#    Fill this section to demonstrate how to use the code.
#
# (Start code)
# (end)
#
# Usage:
# (Start code)
#   usage: perl ServerTemplate.pl [options] [filenames]*
#        -verbose         flag,     switch on verbose mode.
#        -help            flag,     display the online help.
#        -outputDirectory string,   directory for outputs
# (end)
#
# Output:
# (Start code)
# (end)
# ------------------------------------------------------------------------
# To customize: replace the package name
package ScriptTemplate;

use 5.010;
use strict;
use lib "$ENV{'FTF'}/lib";
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
use Script;

# Assertions are on.
use Carp::Assert;

$VERSION = 1;
@ISA     = qw(Script);

# To customize: add your own libraries
use Data::Dumper;
use ExecutionContext;
use ScriptConfiguration;
use Protocol::Utilities;

use Digest::SHA1 qw(sha1 sha1_hex sha1_base64);
use Crypt::CBC;
use Crypt::Ctr;
use Crypt::OpenSSL::AES;
use IPC::Open2;
use Openssl;
use Crypt::OpenSSL::RSA;
use Crypt::OpenSSL::Random;
use Crypt::OpenSSL::DSA;
use Crypt::OpenSSL::X509;
use Crypt::DES_EDE3;


# ------------------------------------------------------------------------
# routine: random_ex
#
#  Example of random generation
# ------------------------------------------------------------------------
sub random_ex {
	print "Pseudo random generation\n";
	my $range = 100;

	srand(100);
	for ( my $i = 0 ; $i < 10 ; $i++ ) {
		my $random_number = int( rand($range) );
		print $random_number . ", ";
	}
	print "\n";

	srand(100);
	for ( my $i = 0 ; $i < 10 ; $i++ ) {
		my $random_number = int( rand($range) );
		print $random_number . ", ";
	}
	print "\n" x 2;
}

# ------------------------------------------------------------------------
# routine: sha1_ex
#
#  Example of SHA1 computation
# ------------------------------------------------------------------------
sub sha1_ex {
	print "SHA1\n";
	my $data = "Hello world";
	$data = hexa2bin("0123456789ABCDEF");
	$data = ("0123456789ABCDEF");
	my $sha1      = sha1($data);
	my $sha1_hexa = bin2hexa($sha1);
	print "sha1 length " . length($sha1) . "\n";
	print "sha1_hexa length " . length($sha1_hexa) . "\n";

	print( "data        = " . bin2hexa($data) . "\n" );
	print( "sha1        = " . $sha1_hexa . "\n" );
	print( "sha1_hex    = " . sha1_hex($data) . "\n" );
	print( "sha1_base64 = " . sha1_base64($data) . "\n" x 2 );
}

# ------------------------------------------------------------------------
# routine: aes_ecb
#
#  Example of AES 128 in ECB mode
# ------------------------------------------------------------------------
sub aes_ecb_ex {
	print "AES-ecb\n";
	my $plaintext = "0123456789ABCDEF";
	my $key       = hexa2bin("000102030405060708090A0B0C0D0E0F");

	my $cipher = new Crypt::OpenSSL::AES($key);

	my $encrypted = $cipher->encrypt($plaintext);
	print "plaintext = " . $plaintext . "\n";
	print "encrypted = " . bin2hexa($encrypted) . "\n";
	print "decrypted = " . $cipher->decrypt($encrypted) . "\n";
}

# ------------------------------------------------------------------------
# routine: aes_cbc
#
#  Example of AES 128 in CBC mode
# ------------------------------------------------------------------------
sub aes_cbc_ex {
	my $plaintext = "0123456789ABCDEF";
	my $key       = hexa2bin("000102030405060708090A0B0C0D0E0F");

	print "AES-cbc\n";
	my $iv        = hexa2bin("00000000000000000000000000000000");
	my $cbcCipher = Crypt::CBC->new(
		-literal_key => 1,
		-key         => $key,
		-iv          => $iv,
		-header      => "none",
		-keysize     => 16,
		-cipher      => "Crypt::OpenSSL::AES"
	);

	print "iv  = " . bin2hexa( $cbcCipher->iv() ) . "\n";
	print "key = " . bin2hexa( $cbcCipher->key() ) . "\n";

	$plaintext .= $plaintext . $plaintext;
	print "plaintext = " . $plaintext . "\n";
	my $encrypted = $cbcCipher->encrypt($plaintext);
	print "encrypted = " . bin2hexa($encrypted) . "\n";
	print "decrypted = " . $cbcCipher->decrypt($encrypted) . "\n";

}

sub image {
	my $key = shift;

	my $res = "";
	while ( length($key) > 16 ) {
		my $start = substr( $key, 0, 16 );
		$res .= bin2hexa($start) . " ";
		$key = substr( $key, 16, length($key) - 16 );
	}
	return $res . bin2hexa($key);
}

# ------------------------------------------------------------------------
# routine: aes_ctr_ex
#
#  Example of AES 128 in CTR mode
# ------------------------------------------------------------------------
sub aes_ctr_ex {

	print "\nAES-ctr\n";

	my $plaintext = hexa2bin("00000000000000000000000000000000");
	my $key       = hexa2bin("5724C47024A1D44DC50C866FC59C21F7");
	$key = hexa2bin("D17955D6B0F887D116FA635FF8D1024C");

	my $iv = hexa2bin("00000000000000000000000000000000");

	my $cipher = new Crypt::Ctr( $key, "Crypt::OpenSSL::AES" );

	my $aes         = new Crypt::OpenSSL::AES($key);
	my $ciphertext2 = $aes->encrypt($plaintext);

	print "ciphertext = " . image($ciphertext2) . "\n";

	$plaintext = $plaintext x 4;
	my $ciphertext = $cipher->encrypt($plaintext);
	print "\nciphertext = " . image($ciphertext) . "\n";

	$ciphertext = $cipher->encrypt($plaintext);
	print "\nciphertext  a second time = " . image($ciphertext) . "\n";

	$cipher->reset();
	$ciphertext = $cipher->encrypt($plaintext);
	print "\nciphertext  after reset = " . image($ciphertext) . "\n";

# Byte by byte
# Warning! I had the erroneous assumption that with a stream cipher, the concatenation
# of block of ciphered text was equal to the cipher of the concatenated block. It is wrong
# and it even seems the different cryptographic libraries have different behaviors in this
# case. So encryption have to be done for the whole block.

	# So the following test is useless
	#    $ciphertext = "";
	#    for (my $i = 0; $i < length($plaintext); $i++) {
	#        $ciphertext .= $cipher->encrypt(substr($plaintext, $i, 1));
	#    }
	#    print "\nciphertext  byte by byte = " . image($ciphertext) . "\n";

	$cipher = new Crypt::Ctr( $key, "Crypt::OpenSSL::AES", 4 );
	$ciphertext = $cipher->encrypt($plaintext);
	print "\nciphertext initialized at 4 = " . image($ciphertext) . "\n";
	$cipher->reset(4);
	my $clear = $cipher->decrypt($ciphertext);
	print "\nclear = " . image($clear) . "\n";

}

# ------------------------------------------------------------------------
# routine: rsa_ex
#
#  Example of RSA
# ------------------------------------------------------------------------
sub rsa_ex {

	print "\nRSA\n";

	my ( $fd, $good_entropy );
	open( $fd, "</dev/random" ) or die("cannot open /dev/random");
	binmode( $fd, ":raw" );
	read( $fd, $good_entropy, 16 );
	close($fd);

	print "entropy=" . bin2hexa($good_entropy) . "\n";

	Crypt::OpenSSL::Random::random_seed($good_entropy);
	Crypt::OpenSSL::RSA->import_random_seed();

	print "Generation of a private/public key pair\n";

	# ------------------------------------------------
	my $rsa = Crypt::OpenSSL::RSA->generate_key(1024);    # or
	     # $rsa = Crypt::OpenSSL::RSA->generate_key( 1024, $prime );

	print "private key is:\n", $rsa->get_private_key_string(), "\n";
	print "public key (in PKCS1 format) is:\n", $rsa->get_public_key_string(),
	  "\n";

	print "public key (in X509 format) is:\n",
	  $rsa->get_public_key_x509_string();

	my $private = "-----BEGIN RSA PRIVATE KEY-----
MIICXQIBAAKBgQC6/teAe7FfDKNHi+YEhKGujwKypcCrDhja/H0tpUlx0pj14jR8
9w7Bs1IYHN+3Rl2KcB0F4kxtZi4fFeoa2YDV2A1baX2FRcIDOePEkWcFpxfA+v8w
CprKPgRJZTxe/CgtKjtKYxSpHtv2++pgH5UQ2eZIUyIFOsZEtWZOCk2YKwIDAQAB
AoGAVzUqg70sB0v5ihBwgYLpdGM1uuMaa6vzY42FQ5hmHDM/Ks0H9Y+yzhs3Gg+9
NdgXH80RfAEB67NPpyetOkBdmJE1b6mGwa9dZ86xNiTDw4izJKKNryIOQeWrrjSk
7KxEca2ISHP9yCwhLDsXOymH7zYYzruPbtmiH/P51RYxiuECQQDhCZ+eDMieyc4X
EbzlkaOv7e/cm758rS34Vtbbh3nCf7cMR/zvgFA9TYJw67S8r7QjeYtNuoEZnflC
yHJ1cbTPAkEA1LlIFRggeYvl1R4K1maEZzXENKYZ8eyjpL9FtSJoP0+PdmqopUeo
CKTMjeoDMUjtoa+ateHq6MNNTmr9llg15QJBAMbDNj1l8yj0+9e6bgqiiV5RnWNQ
GH6Mg6buJJX/4dad8XKiftCXl8edl1HfjmJ+GnCe4SCFU5PpyQhofVgoV1cCQQDL
SOjWp8DZBtUzbctDiqK7EwmWmqkupUrZNKSD7gabggeCTXkuwaSV5g9JCznTznKw
0eTSLbxUhdcJunruQwv1AkA0T3ywLpoJTk/bf8nBK7jtCe2jVvSltv7CORkZk78i
+5YMlLgv65w2t6vcI8/qiUok3tluaWlwAqueS8+YDVI1
-----END RSA PRIVATE KEY-----";

	my $public = "-----BEGIN RSA PUBLIC KEY-----
MIGJAoGBALr+14B7sV8Mo0eL5gSEoa6PArKlwKsOGNr8fS2lSXHSmPXiNHz3DsGz
Uhgc37dGXYpwHQXiTG1mLh8V6hrZgNXYDVtpfYVFwgM548SRZwWnF8D6/zAKmso+
BEllPF78KC0qO0pjFKke2/b76mAflRDZ5khTIgU6xkS1Zk4KTZgrAgMBAAE=
-----END RSA PUBLIC KEY-----";

	my $plaintext = "The quick brown fox jumps over the lazy dog";

	# $plaintext = $plaintext x 8;
	print "plain text: " . " length=" . length($plaintext) 
	. ", text = " . $plaintext . "\n";

	# Encrypt a message using the public key
	my $rsa_pub = Crypt::OpenSSL::RSA->new_public_key($public);

 #    $rsa_pub->use_sslv23_padding();    # use_pkcs1_oaep_padding is the default
	$rsa_pub->use_pkcs1_padding();
	$rsa_pub->use_md5_hash();

	my $ciphertext = $rsa_pub->encrypt($plaintext);
	print "cipher text: length="
	  . length($ciphertext) . "\n"
	  . bin2hexa($ciphertext) . "\n";

	# Decrypt it using the private key
	my $rsa_priv = Crypt::OpenSSL::RSA->new_private_key($private);
	$rsa_priv->use_pkcs1_padding();
	$rsa_priv->use_md5_hash();    # use_sha1_hash is the default
	$plaintext = $rsa_priv->decrypt($ciphertext);
	print "plain text again = " . $plaintext . "\n";

	# Sign the message
	my $signature = $rsa_priv->sign($plaintext);
	print "signature = "
	  . length($signature) . "\n"
	  . bin2hexa($signature) . "\n";
	if ( $rsa_priv->verify( $plaintext, $signature ) ) {
		print "Signed correctly\n";
	}
	else {
		print "bad signature\n";
	}

	# Encrypt with private, decrypt with public
	$ciphertext = $rsa_priv->private_encrypt($plaintext);
	print "cipher text = "
	  . length($ciphertext) . "\n"
	  . bin2hexa($ciphertext) . "\n";
	my $bin = $rsa_pub->public_decrypt($ciphertext);
	print "(clear again) $bin\n";
	if ( $rsa_pub->verify( $bin, $signature ) ) {
		print "Signed correctly\n";
	}
	else {
		print "bad signature\n";
	}

}

# ------------------------------------------------------------------------
# routine: rsa_ex
#
#  Example of DSA
# ------------------------------------------------------------------------
sub dsa_ex {

	print "\nDSA\n";

	my $dsa    = Crypt::OpenSSL::DSA->generate_parameters(1024);
	$dsa->generate_key;

	$dsa->write_pub_key("pub.txt");
	$dsa = Crypt::OpenSSL::DSA->read_pub_key("pub.txt");

	$dsa->write_priv_key("priv.txt");
	$dsa->write_params("params.txt");

	my $pemfile = "cryptotestkey-cert.pem";
	$pemfile = "pub.txt";

	my $cmd = "cat $pemfile;";
	print "reading $pemfile $cmd\n";
	`$cmd`;
	$dsa = Crypt::OpenSSL::DSA->read_pub_key($pemfile);
	if ($@) {
		die "error $@";
	}
	print Dumper($dsa);

	return;

	( -e $pemfile ) or die "Cannot find $pemfile";
	my $dsa_priv = Crypt::OpenSSL::DSA->read_priv_key($pemfile);
	print Dumper($dsa_priv);
	my $dsa_pub = Crypt::OpenSSL::DSA->read_pub_key($pemfile);
	if ($@) {
		die "error $@";
	}
	print Dumper($dsa_pub);

	#    c key from certificate = " . bin2hexa($pub_key) . "\n";

}

# ------------------------------------------------------------------------
# routine: rsa_ex
#
#  Example of DSA
# ------------------------------------------------------------------------
sub x509_ex {

	print "\nX509\n";

	my $pemfile = "cryptotestkey-cert.pem";
	my $x509 = Crypt::OpenSSL::X509->new_from_file($pemfile);

	print "pubkey=" . $x509->pubkey() . "\n";
	print "subject=" . $x509->subject() . "\n";
	print "issuer=" . $x509->issuer() . "\n";
	print "email=". $x509->email() . "\n";
	print "hash=" . $x509->hash() . "\n";
	print "notBefore=" . $x509->notBefore() . "\n";
	print "notAfter=" . $x509->notAfter() . "\n";
	print "modulus=" . $x509->modulus() . "\n";
	# print $x509->exponent() . "\n";
	print "fingerprint_sha1=" . $x509->fingerprint_sha1() . "\n";
	print "fingerprint_md5=" . $x509->fingerprint_md5() . "\n";
#	print "fingerprint_md2=" . $x509->fingerprint_md2() . "\n";
	print "as_string=" . $x509->as_string(Crypt::OpenSSL::X509::FORMAT_TEXT) . "\n";
	
	my $pubkey = $x509->pubkey();
		
    print "pubkey = $pubkey\n";
    
	my $rsa_pub = Crypt::OpenSSL::RSA->new_public_key($pubkey);
    print Dumper($rsa_pub);	
}

# ------------------------------------------------------------------------
# routine: tdes
#
#  Example of TDES
# ------------------------------------------------------------------------
sub tdes {
    say "TDES";
    my $clear = hexa2bin("CC0200CE0002181A");    
    
    my $key16 = hexa2bin("DE1A3AA37229FF4EB9B1AB04ECFC7D53");
    my $key24 = hexa2bin("DE1A3AA37229FF4EB9B1AB04ECFC7D53DE1A3AA37229FF4E");
    
    my $ede3 = Crypt::DES_EDE3->new($key24);
    say ("clear=" . bin2hexa($clear));
    say ("TDES key =" . bin2hexa($key24));
    say ("length=" . length($clear));
    my $encrypted =  $ede3->encrypt($clear);
    say("encrypted=" . bin2hexa($encrypted));
    
    my $clear2 = $ede3->decrypt($encrypted);
    say ("decrypted=" . bin2hexa($clear2));
}

# ------------------------------------------------------------------------
# routine: run
#
#  Scrip main method. It is an example which recursively parse a
#  set of directories and apply a treatement to each file.
#  To customize:
# ------------------------------------------------------------------------
sub run {
	my $Self = shift;

	my $name = ExecutionContext::basename();
	print "Hello I am a cryptographic example\n\n";

	$Self->info("starting $name");
	assert( $name ne "" );

    tdes();
    return;
	    random_ex();
	    sha1_ex();
	    aes_ecb_ex();
	    aes_cbc_ex();
	    aes_ctr_ex();
	dsa_ex();
	x509_ex();

	rsa_ex();

	$Self->info("$name is completed");
}

# ------------------------------------------------------------------------
# On line help and options.
# The full online help is the catenation of the header,
# the parameters description and the footer. Parameters description
#  is automatically computed.

# To customize: you can remove help specification, remove the
# configuration file, remove additional parameters and even remove
# everything related to configuration.
my $help_header = '
Script template. 

usage: perl ScriptTemplate.pl [options]';

my $help_footer = "
Exemple:

    perl ScriptTemplate.pl -help
    perl ScriptTemplate.pl -pattern 'o customize' my_script.pl
";

# If you specify a configuration file, it must exist.
my $configFile = ExecutionContext::configFile();

my $config = new ScriptConfiguration(
	'header'     => $help_header,
	'footer'     => $help_footer,
	'scheme'     => SCRIPT,
	'parameters' => {
		pattern => {
			type        => "string",
			description => "pattern to search",
			default     => "pattern"
		},
		fail => {
			type        => "flag",
			description => "force some assertions to fail",
		}
	},
);

# create and run the script
# To customize: replace by your package name
my $script = new ScriptTemplate( pattern => $config->value('pattern') );
$script->{'fail'} = $config->value('fail');
$script->run();
