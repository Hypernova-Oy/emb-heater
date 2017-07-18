#!/usr/bin/perl

use Modern::Perl;

use Test::More;
use Test::MockModule;

use t::Examples;

use Heater;


my $heater = t::Examples::getHeater();

my ($sensor1ID, $sensor2ID);


subtest "Story about a Heater named Heather which stands guard obedient and stalwart through a year of changing weather conditions", \&storyOfHeather;
sub storyOfHeather {

  #Feature:
  #  -Heater must stop heating if either temperature sensor starts to malfunction
  #  -Heater must stop heating if any temperature sensor reaches or exceeds the emergency threshold
  #  -Heater can start heating when any temperature sensor goes below the heating threshold
  #  -Heater must stop heating when all temperature sensors go above the heating stop threshold

  my ($module, $sensors, $op);
  $module = Test::MockModule->new('HiPi::Interface::DS18X20');

  eval {

  ok($heater,
     "Given Heater Heather, a stalwart protector of the barcode reader and other cold intolerant components.");

  ok($sensors = $heater->getTemperatureSensors(),
     "Given Heather has two temperature sensors, one for the PCB and the other for the heating element.");

  $sensor1ID = $sensors->[0]->{id};
  $sensor2ID = $sensors->[1]->{id};

  ok(!$heater->isWarming(),
     "Given Heather is not warming by default");

  subtest "Scenario: Finnish summer has no cold, temperatures are stably high.", sub {
    ok($module->mock('temperature', makeTempsMockerSub(17, 17)), #Both sensors return +17℃
       "Given the ambient temperature is at +17");

    is($heater->measureState(), Heater::NOOP,
       "Then Heather can wait patiently");
  };


  subtest "Scenario: Finnish autumn is nice and dark, temperatures are stably ok, Heather doesn't understand humidity.", sub {
    ok($module->mock('temperature', makeTempsMockerSub(7, 7)),
       "Given the ambient temperature is at +7");

    is($heater->measureState(), Heater::NOOP,
       "Then Heather can wait patiently");
  };


  subtest "Scenario: Finnish winter is merciless and cold, temperatures are deadly, Heather might care about humidity, if it wasn't so cold.", sub {
    ok($module->mock('temperature', makeTempsMockerSub(-17, -17)),
       "Given the ambient temperature is at -17");
    is($heater->measureState(), Heater::NOOP,
       "Then Heather can wait patiently");

    ok($module->mock('temperature', makeTempsMockerSub(-21, -21)),
       "Given the ambient temperature drops to -21");
    is($heater->measureState(), Heater::TURN_WARMING_ON,
       "Then Heather must start heating");

    ok($module->mock('temperature', makeTempsMockerSub(-21, -16.8)),
       "Given the heater is heating and heating sensor reads -16.8, just below the heating stop threshold");
    is($heater->measureState(), Heater::NOOP,
       "Then Heather keeps heating, because other sensors are still too cold");

    ok($module->mock('temperature', makeTempsMockerSub(-19, +10)),
       "Given the heater is heating and heating sensor reads +10");
    is($heater->measureState(), Heater::NOOP,
       "Then Heather keeps heating, until all sensors are warm enough");

    ok($module->mock('temperature', makeTempsMockerSub(-16.98, +20)),
       "Given the heater is heating and heating sensor reads +20, other sensor -16.98, just below the heating stop threshold");
    is($heater->measureState(), Heater::TURN_WARMING_OFF,
       "Then Heather stops heating");

    ok($module->mock('temperature', makeTempsMockerSub(-19, +10)),
       "Given Heather starts to get cold again, but not too cold");
    is($heater->measureState(), Heater::NOOP,
       "Then Heather waits");

    ok($module->mock('temperature', makeTempsMockerSub(-21, +20)),
       "Given one sensor drops to -21");
    is($heater->measureState(), Heater::TURN_WARMING_ON,
       "Then Heather starts heating");

    ok($module->mock('temperature', makeTempsMockerSub(-22, +60)),
       "Given one sensor drops to -22, while Heather is warming really hard");
    is($heater->measureState(), Heater::NOOP,
       "Then Heather keeps heating");

    ok($module->mock('temperature', makeTempsMockerSub(-21, +86)),
       "Given heater sensor rises to +86");
    is($heater->measureState(), Heater::EMERGENCY_STOP,
       "Then Heather emergency shuts down heating");

    ok($module->mock('temperature', makeTempsMockerSub(-21, +59)),
       "Given heater sensor drops to +59");
    is($heater->measureState(), Heater::TURN_WARMING_ON,
       "Then Heather starts heating");

    ok($module->mock('temperature', makeTempsMockerSub(-16, +88)),
       "Given heater sensor exceeds the emergency threshold and other sensors exceed the heating stop threshold");
    is($heater->measureState(), Heater::EMERGENCY_STOP,
       "Then Heather emergency shuts down heating");

    ok($module->mock('temperature', makeTempsMockerSub(-16, -16)),
       "Given ambient temperature decreases and sensors adjust to it");
    is($heater->measureState(), Heater::NOOP,
       "Then Heather patiently waits");

    ok($module->mock('temperature', makeTempsMockerSub(-25, -25)),
       "Given ambient temps decrease rapidly and one sensor has malfunctioned");
    is($heater->measureState(), Heater::EMERGENCY_STOP,
       "Then Heather starts heating");

    ok($module->mock('temperature', makeTempsMockerSub(undef, -20)),
       "Given one sensor has just malfunctioned");
    is($heater->measureState(), Heater::EMERGENCY_STOP,
       "Then Heather emergency shuts down heating");

    ok(1, "-Heather is malfunctioning and waiting for maintenance-");
    ok(1, "Given Heather is fixed and rebooted, the sensors are loaded in different order");

    ok($module->mock('temperature', makeTempsMockerSub(-25, -25)),
       "Ambient temperature drops again");
    is($heater->measureState(), Heater::TURN_WARMING_ON,
       "Then Heather starts warming");

    ok($module->mock('temperature', makeTempsMockerSub(+20, -16)),
       "Given warming is effective");
    is($heater->measureState(), Heater::TURN_WARMING_OFF,
       "Then Heather stops warming");
  };

  subtest "Scenario: Finnish spring is wet, Heather likes it.", sub {
    ok($module->mock('temperature', makeTempsMockerSub(5, 6)),
       "Given the ambient temperature is at +5");

    is($heater->measureState(), Heater::NOOP,
       "Then Heather can wait patiently for the Winter is Coming");
  };

  };
  ok(0, $@) if $@;
}




done_testing;





=head2 makeTempsMockerSub

@PARAMS List of temperatures the specific temperature sensors should return
@RETURNS Anonymous subroutine (closure) which replaces the mocked subroutine.

=cut

sub makeTempsMockerSub {
    my @temps = @_;
    return sub {
        return $temps[0] if ($_[0]->{id} eq $sensor1ID);
        return $temps[1] if ($_[0]->{id} eq $sensor2ID);
        #return $temps[2] if ($_[0]->{id} eq $sensor3ID);
    };
}

