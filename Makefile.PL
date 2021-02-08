use ExtUtils::MakeMaker;
use 5.004;

my @ppd;

if ($] >= 5.00503) {
  @ppd = (
    AUTHOR    => 'Frédéric Peignot',
    ABSTRACT  => 'Perl Test Framework'
  );
}

my $missing = 0;
my @modules = qw(Test::Harness Log::Log4perl Tcl HTTP::Daemon Unix::Process);

foreach my $mod (@modules) {
	eval {
		require $mod;
	};
	if ($@) {
		print "required module $mod not found\n";
		$missing = 1;
	}
}
print "Missing modules, it is recommended to install them to get the all the framework services.\n\n" if $missing;


WriteMakefile(
	NAME	     => 'Freds_Test_Framework',
	VERSION_FROM => 'lib/Script.pm',
	@ppd
);

sub MY::postamble {

  return '' unless $] >= 5.00503;

<<'ESQ';

dist : ppd

ESQ
}

