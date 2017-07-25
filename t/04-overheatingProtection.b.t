#!/usr/bin/perl

use Modern::Perl;

use Test::More;
use Test::MockModule;

use t::Examples;
use t::Mocks;

use Heater;

$ENV{HEATER_TEST_MODE} = 1;
#$ENV{HEATER_LOG_LEVEL} = 6; #Full logging to stdout

my $heater = t::Examples::getHeater();

subtest "Story about a Heater named Heather which stands guard obedient and stalwart through a year of changing weather conditions", \&storyOfHeather;
sub storyOfHeather {

  #Feature:
  #  -Heater must stop heating if either temperature sensor starts to malfunction
  #  -Heater must stop heating if any temperature sensor reaches or exceeds the emergency threshold
  #  -Heater can start heating when any temperature sensor goes below the heating threshold
  #  -Heater must stop heating when all temperature sensors go above the heating stop threshold
  #
  #  Encompasses all state transitions defined in doc/Heater.png

  my ($module, $sensors, $op, $statisticsInMemLog);
  $module = Test::MockModule->new('HiPi::Interface::DS18X20');


  ### Mock Heater::Statistics to write to a variable instead of a file
  my $moduleStatisticsOverload = Test::MockModule->new('Heater::Statistics');
  $moduleStatisticsOverload->mock('_getStatFileHandle', sub {
    my ($FH, $ptr) = t::Mocks::reopenScalarHandle(undef, \$statisticsInMemLog);
    return $FH;
  });

  eval {

  ok($heater,
     "Given Heater Heather, a stalwart protector of the barcode reader and other cold intolerant components.");

  ok($sensors = $heater->getTemperatureSensors(),
     "Given Heather has two temperature sensors, one for the PCB and the other for the heating element.");
  $ENV{TEST_SENSOR_IDS} = $sensors;

  ok(!$heater->isWarming(),
     "Given Heather is not warming by default");

  subtest "Scenario: Finnish summer has no cold, temperatures are stably high.", sub {
    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(17, 17)), #Both sensors return +17℃
       "Given the ambient temperature is at +17");

    ok(newTickAndTestState($heater, $Heater::STATE_IDLE, 0),
       "Then Heather can wait patiently");
  };


  subtest "Scenario: Finnish autumn is nice and dark, temperatures are stably ok, Heather doesn't understand humidity.", sub {
    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(7, 7)),
       "Given the ambient temperature is at +7");

    ok(newTickAndTestState($heater, $Heater::STATE_IDLE, 0),
       "Then Heather can wait patiently");
  };


  subtest "Scenario: Finnish winter is merciless and cold, temperatures are deadly, Heather might care about humidity, if it wasn't so cold.", sub {
    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(-17, -17)),
       "Given the ambient temperature is at -17");
    ok(newTickAndTestState($heater, $Heater::STATE_IDLE, 0),
       "Then Heather can wait patiently");

    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(-21, -21)),
       "Given the ambient temperature drops to -21");
    ok(newTickAndTestState($heater, $Heater::STATE_WARMING, 1),
       "Then Heather must start heating");

    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(-21, -16.8)),
       "Given the heater is heating and heating sensor reads -16.8, just below the heating stop threshold");
    ok(newTickAndTestState($heater, $Heater::STATE_WARMING, 1),
       "Then Heather keeps heating, because other sensors are still too cold");

    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(-19, +10)),
       "Given the heater is heating and heating sensor reads +10");
    ok(newTickAndTestState($heater, $Heater::STATE_WARMING, 1),
       "Then Heather keeps heating, until all sensors are warm enough");

    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(-16.98, +20)),
       "Given the heater is heating and heating sensor reads +20, other sensor -16.98, just below the heating stop threshold");
    ok(newTickAndTestState($heater, $Heater::STATE_IDLE, 0),
       "Then Heather stops heating");

    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(-19, +10)),
       "Given Heather starts to get cold again, but not too cold");
    ok(newTickAndTestState($heater, $Heater::STATE_IDLE, 0),
       "Then Heather waits");

    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(-21, +20)),
       "Given one sensor drops to -21");
    ok(newTickAndTestState($heater, $Heater::STATE_WARMING, 1),
       "Then Heather starts heating");

    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(-22, +60)),
       "Given one sensor drops to -22, while Heather is warming really hard");
    ok(newTickAndTestState($heater, $Heater::STATE_WARMING, 1),
       "Then Heather keeps heating");

    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(-21, +86)),
       "Given heater sensor rises to +86");
    ok(newTickAndTestState($heater, $Heater::STATE_EMERGENCY_SHUTDOWN, 0),
       "Then Heather emergency shuts down heating");

    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(-21, +59)),
       "Given heater sensor drops to +59");
    ok(newTickAndTestState($heater, $Heater::STATE_WARMING, 1),
       "Then Heather starts heating");

    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(-16, +88)),
       "Given heater sensor exceeds the emergency threshold and other sensors exceed the heating stop threshold");
    ok(newTickAndTestState($heater, $Heater::STATE_EMERGENCY_SHUTDOWN, 0),
       "Then Heather emergency shuts down heating");

    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(-16, -16)),
       "Given ambient temperature decreases and sensors adjust to it");
    ok(newTickAndTestState($heater, $Heater::STATE_IDLE, 0),
       "Then Heather patiently waits");

    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(undef, -18)),
       "Given one sensor has malfunctioned");
    try {
      newTickAndTestState($heater, 'not tested', 'not tested'), #internal state tests are not executed because main loop crashes
      ok(0, "Main loop should throw an Exception!");
    } catch {
      is(ref($_), 'Heater::Exception::Hardware::TemperatureSensor',
         "Then Heather throws the expected hardware exception");
      is($_->sensorId, $ENV{TEST_SENSOR_IDS}->[0]->id,
         "And the expected sensor faulted");
    };

    ok(1, "-Heather is malfunctioning and waiting for maintenance-");
    ok($heater = t::Examples::getHeater(),
       "Given Heather is fixed and rebooted, the sensors are loaded in different order");

    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(-25, -25)),
       "Ambient temperature drops again");
    ok(newTickAndTestState($heater, $Heater::STATE_WARMING, 1),
       "Then Heather starts warming");

    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(+20, -16)),
       "Given warming is effective");
    ok(newTickAndTestState($heater, $Heater::STATE_IDLE, 0),
       "Then Heather stops warming");
  };

  subtest "Scenario: Finnish spring is wet, Heather likes it.", sub {
    ok($module->mock('temperature', t::Mocks::makeTempsMockerSub(5, 6)),
       "Given the ambient temperature is at +5");

    ok(newTickAndTestState($heater, $Heater::STATE_IDLE, 0),
       "Then Heather can wait patiently for the Winter is Coming");
  };

  };
  ok(0, $@) if $@;
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
