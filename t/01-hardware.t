#!/usr/bin/perl

use Test::More;

use Heater;


print "These are manual tests and there is no convenient way of automatically confirming that the relay is actually working.\n";
print "Connect the relay on to GPIO pin 16 and relay off to GPIO pin 18";
print "\n\n";
print "Test begins...\n";


my $heater = Heater->new({
                 SwitchOnRelayBCMPin => 23,
                 SwitchOffRelayBCMPin => 24,
                 ActivationTemperature => -20,
                 TargetTemperature => -17,
                 TemperatureCorrection => 100,
                 StatisticsWriteInterval => -1,
             });



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
