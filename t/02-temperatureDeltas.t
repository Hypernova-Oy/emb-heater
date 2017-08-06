#!/usr/bin/perl

use Modern::Perl;

use Test::More;
use Test::MockModule;

use t::Examples;
use t::Mocks;

use Heater;
use Heater::Transitions;
use Heater::Exception;

$ENV{HEATER_TEST_MODE} = 1;
#$ENV{HEATER_LOG_LEVEL} = 'TRACE'; #Full logging to stdout


### Mock Heater::Statistics to write to a variable instead of a file
my $moduleStatisticsOverload = Test::MockModule->new('Heater::Statistics');
my $statisticsInMemLog = '';
t::Mocks::mockStatisticsFileWritingToScalar($moduleStatisticsOverload, \$statisticsInMemLog);


my $heater = t::Examples::getHeater();


subtest "Check correct heating activation and termination thresholds", \&deltaToTarget;
sub deltaToTarget {

  my ($module);

  eval {
  $module = Test::MockModule->new('Heater');



  ok(! $module->mock('temperatures', sub { return [20.0] }),
    "It is 20 degrees warm - no need to heat");

  ok(Heater::Transitions::_reachedTargetTemp($heater),
    "We have reached our target temperature");
  is($Heater::Transitions::deltaToTargetTemperature, -37,
    "We are '-37' degrees away to 'hot-enough threshold'");

  ok(! Heater::Transitions::_reachedActivationTemp($heater),
    "We shouldn't start heating now");
  is($Heater::Transitions::deltaToActivationTemperature, -40,
    "We are '-40' degrees away to start heating");



  ok(! $module->mock('temperatures', sub { return [-30.0] }),
    "It is -30 degrees warm - heat!");

  ok(! Heater::Transitions::_reachedTargetTemp($heater),
    "We are far from our target temperature!");
  is($Heater::Transitions::deltaToTargetTemperature, 13,
    "We are '13' degrees heating away to stop heating");

  ok(Heater::Transitions::_reachedActivationTemp($heater),
    "We should start heating now");
  is($Heater::Transitions::deltaToActivationTemperature, 10,
    "We are '10' degrees too cold");



  };
  ok(0, Heater::Exception::toText($@)) if $@;
}



done_testing;
