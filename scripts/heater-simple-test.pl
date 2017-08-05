#!/usr/bin/perl

## IN THIS FILE ##
#
# Super simple heater test to verify hardware connections. Do not use in production!
#

use Modern::Perl;

use HiPi::Interface::DS18X20;

my @slaves = HiPi::Interface::DS18X20->list_slaves();

for (my $i=0 ; $i<@slaves ; $i++) {
    $slaves[$i] = HiPi::Interface::DS18X20->new(
                      id => $slaves[$i]->{id},
                      divider => 1000
                  );

    my $t = $slaves[$i]->temperature();
    print "Slave '".$slaves[$i]->id()."' temperature '".$slaves[$i]->temperature()."'\n";
}

