#!/usr/bin/perl

use Modern::Perl;

use Test::More;

use t::Examples;

use Heater;


print "These are manual tests and there is no convenient way of automatically confirming that the relay is actually working.\n";
print "Connect the relay on to GPIO pin 16 and relay off to GPIO pin 18";
print "\n\n";
print "Test begins...\n";


my $heater = t::Examples::getHeater();


subtest "Testing temperature sensor", \&tempSensor;
sub tempSensor {

  my $tempSensorId = Heater::getTemperatureSensorID();
  ok($tempSensorId, "Got a temperature sensor id '$tempSensorId'");

  my $temp = $heater->getTemperatureSensor()->temperature();
  ok($temp, "Got a temperature reading '$temp'");

}


subtest "Testing relay", \&relay;
sub relay {

  ok($heater->turnWarmingOn(), "Warming turned on");
  sleep 1;
  ok($heater->turnWarmingOff(), "Warming turned off");

}


subtest "Turning on heater for 1 minute and observing if there is any temperature change", \&relayWithTemp;
sub relayWithTemp {

  my $startingTemp = $heater->getTemperatureSensor()->temperature();
  ok($startingTemp, "Got a starting temperature reading '$startingTemp'");

  ok($heater->turnWarmingOn(), "Warming turned on for one minute. Observe that the heater starts to heat.");
  sleep 60;
  ok($heater->turnWarmingOff(), "Warming turned off");

  my $endingTemp = $heater->getTemperatureSensor()->temperature();
  ok($endingTemp, "Got a ending temperature reading '$endingTemp'");

  ok($endingTemp > $startingTemp, "Ending temperature is higher than starting temperature. This test succeeds only when the heater can actually heat the temperature sensor.")
}


done_testing;
