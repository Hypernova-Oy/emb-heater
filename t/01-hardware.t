#!/usr/bin/perl

use Modern::Perl;
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

use Test::More;

use t::Examples;

use Heater;
use Heater::Exception;


my $heater = t::Examples::getHeater();


print "These are manual tests and there is no convenient way of automatically confirming that the relay is actually working.\n";
print "Connect the relay on to GPIO pin 16 and relay off to GPIO pin 18";
print "\n\n";
print "Test begins...\n";

eval {

subtest "Testing temperature sensor", \&tempSensor;
sub tempSensor {

  my $sensors = $heater->getTemperatureSensors();
  ok(scalar(@$sensors), "Found '".scalar(@$sensors)."' temperature sensors.");

  my $temps = $heater->temperatures('withQuantum');
  my $tempsString = join(", ", @$temps);
  ok(scalar(@$temps), "Got temperature readings '$tempsString'");
  like($tempsString, qr/℃/, "Temperature reading with a quantifier");

}

subtest "Testing relay", \&relay;
sub relay {

  ok($heater->turnWarmingOn(), "Warming turned on");
  sleep 1;
  ok($heater->turnWarmingOff(), "Warming turned off");

}


subtest "Turning on heater for 1 minute and observing if there is any temperature change", \&relayWithTemp;
sub relayWithTemp {

  my $sensors = $heater->getTemperatureSensors();
  my $startingTemps = $heater->temperatures();
  my $startingTempsString = join(', ',@$startingTemps);
  ok(scalar(@$startingTemps), "Got starting temperature readings '$startingTempsString'");

  ok($heater->turnWarmingOn(), "Warming turned on for one minute. Observe that the heater starts to heat.");
  sleep 60;
  ok($heater->turnWarmingOff(), "Warming turned off");

  my $endingTemps = $heater->temperatures();
  my $endingTempsString = join(', ',@$endingTemps);
  ok(scalar(@$endingTemps), "Got ending temperature readings '$endingTempsString'");

  ##These tests succeed only when the heater can actually heat all temperature sensors.
  for(my $i=0 ; $i<scalar(@$startingTemps) ; $i++) {
    my $st = $startingTemps->[$i];
    my $et = $endingTemps->[$i];
    my $s = $sensors->[$i];
    ok($et > $st, "Ending temperature is higher than starting temperature for sensor '".$s->id."'.");
  }
}

};
if ($@) {
  ok(0, Heater::Exception::toText($@)) if $@;
}
$heater->turnWarmingOff(); #Make sure the heater is turned off

done_testing;
