use Device::USB;
use Data::Dumper;

my $usb = Device::USB->new();

my $busses = $usb->list_busses();
print Dumper($busses), "\n";
exit;

sub find_devices
{
    my $which = shift;
    my @uniqs = ();

    foreach my $bus (@_)
    {
        next unless @{$bus->devices()};
        foreach my $dev ($bus->devices())
        {
            my $vendor = $dev->idVendor();
            my $product = $dev->idProduct();
            print "vendor = $vendor, product=$product\n";
            next if grep { $_->[0] == $vendor and $_->[1] == $product }
                    @uniqs;
            return $dev unless $which--;
            push @uniqs, [ $vendor, $product ];
        }
    }

    return;
}

find_devices();
exit;
my $dev = $usb->find_device( $VENDOR, $PRODUCT );

printf "Device: %04X:%04X\n", $dev->idVendor(), $dev->idProduct();
$dev->open();
print "Manufactured by ", $dev->manufacturer(), "\n",
  " Product: ", $dev->product(), "\n";

$dev->set_configuration($CFG);
$dev->control_msg(@params);
