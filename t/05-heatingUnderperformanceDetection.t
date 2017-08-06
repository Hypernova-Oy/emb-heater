#!/usr/bin/perl

use Modern::Perl;

use Test::More;
use Test::MockModule;
use Try::Tiny;

use t::Examples;
use t::Mocks;

use Heater;
use Heater::Exception;

$ENV{HEATER_TEST_MODE} = 1;
$ENV{HEATER_LOG_LEVEL} = 'TRACE'; #Full logging to stdout
our $TEST_SENSORS;

### Mock Heater::Statistics to write to a variable instead of a file
my $moduleStatisticsOverload = Test::MockModule->new('Heater::Statistics');
my $statisticsInMemLog = '';
t::Mocks::mockStatisticsFileWritingToScalar($moduleStatisticsOverload, \$statisticsInMemLog);


my $heater = t::Examples::getHeater();

subtest "Trigger heating element malfunction, because temperature doesn't rise enough", \&triggerHeatingElementMalfunction;
sub triggerHeatingElementMalfunction {

  my ($module, $sensors, $op);
  $module = Test::MockModule->new('HiPi::Interface::DS18X20');

  eval {

  ok($heater,
     "Given Heater Heather, a stalwart protector of the barcode reader and other cold intolerant components.");

  ok($sensors = $heater->getTemperatureSensors(),
     "Given Heather has two temperature sensors, one for the PCB and the other for the heating element.");
  $TEST_SENSORS = $sensors;

  ok(! $module->mock('temperature', t::Mocks::makeTempsMockerSub(-22, -22)),
     "Given the ambient temperature is at -22");

  ok(newTickAndTestState($heater, $Heater::STATE_WARMING, 1),
     "Then Heather starts heating");

  ok($heater->state->setStarted(time - 50),
     "Given Heather has heated for 50 seconds");

  ok(newTickAndTestState($heater, $Heater::STATE_WARMING, 1),
     "Then Heather keeps on heating");

  ok($heater->state->setStarted(time - 120),
     "Given Heather has heated for 120 seconds");

  try {
    newTickAndTestState($heater, 'not tested', 'not tested'), #internal state tests are not executed because main loop crashes
    ok(0, "Main loop should throw an Exception!");
  } catch {
    is(ref($_), 'Heater::Exception::Hardware::HeatingElement',
       "Then Heather throws the expected hardware exception");
    Heater::Exception::rethrowDefaults($_) unless (ref($_) eq 'Heater::Exception::Hardware::HeatingElement');

    is($_->expectedTemperatureRise, 2,
       "And the expected temperature rise is as expected");
    is($_->biggestMeasuredTemperatureRise, 0,
       "And the biggest measured temperature rise is as expected");
    is($_->heatingDuration, 120,
       "And the heating duration is as expected");
  };



  ok($heater->state->setStarted(time - 180),
     "Given Heather has heated for 180 seconds");

  ok(! $module->mock('temperature', t::Mocks::makeTempsMockerSub(-19.5, -22)),
     "Given the heater heats a bit, but not enough");

  try {
    newTickAndTestState($heater, 'not tested', 'not tested'), #internal state tests are not executed because main loop crashes
    ok(0, "Main loop should throw an Exception!");
  } catch {
    is(ref($_), 'Heater::Exception::Hardware::HeatingElement',
       "Then Heather throws the expected hardware exception");
    Heater::Exception::rethrowDefaults($_) unless (ref($_) eq 'Heater::Exception::Hardware::HeatingElement');

    is($_->expectedTemperatureRise, 3,
       "And the expected temperature rise is 3 Celsius");
    is($_->biggestMeasuredTemperatureRise, 2.5,
       "And the biggest measured temperature rise is 2.5 Celsius");
    is($_->heatingDuration, 180,
       "And the heating duration is 180 seconds");
  };


  ok($heater->state->setStarted(time - 240),
     "Given Heather has heated for 240 seconds");

  ok(! $module->mock('temperature', t::Mocks::makeTempsMockerSub(-14, -20)),
     "Given the heater heats enough");

  newTickAndTestState($heater, $Heater::STATE_WARMING, 1);

  };
  ok(0, Heater::Exception::toText($@)) if $@;
}




done_testing;



=head2 newTickAndTestState

Make Heater do all the tests and checks and transitions.
Then test if the Heater is in the desired internal state.

=cut

sub newTickAndTestState {
  my ($heater, $state, $isWarming) = @_;
  $heater->mainLoop();
  return t::Mocks::testState($heater, $state, $isWarming);
}
