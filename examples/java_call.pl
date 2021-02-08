#!/usr/bin/perl

use strict;
use warnings;

use Inline Java => <<'EOJ';
public class Hi {
    
        // The class body is shown in the Java Code above
        String greeting;
        int cnt = 0;

        public Hi(String greeting) {
            this.greeting = greeting;
        }

        public void setGreeting(String newGreeting) {
            greeting = newGreeting;
        }

        public String getGreeting() {
            return greeting;
        }
        
        public int inc () {
            System.out.println("inc");
            return cnt++;
        }

        public int inc (int v) {
            System.out.println("inc (" + v + ")");
            cnt += v;
            return cnt;
        }
        
        public void list (int value, int [] l) {
            for (int i = 0; i < l.length; i++) {
                System.out.println (i + " = " + (l[i] + value));
            }
        }
}

EOJ

my $greeter = Hi->new("howdy");

print $greeter->getGreeting(), "\n";

print "counter = " . $greeter->inc() . "\n";
print "counter = " . $greeter->inc(7) . "\n";
for ( my $i = 0 ; $i < 3 ; $i++ ) {
    print "counter = " . $greeter->inc() . "\n";
}

my $list = [1, 2, 3, 4, 5];

$greeter->list (42, $list);

