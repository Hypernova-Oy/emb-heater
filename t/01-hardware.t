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



done_testing;
