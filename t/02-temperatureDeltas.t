#!/usr/bin/perl

use Modern::Perl;

use Test::More;
use Test::MockModule;

use t::Examples;

use Heater;


my $heater = t::Examples::getHeater();



subtest "Check correct heating activation and termination thresholds", \&deltaToTarget;
sub deltaToTarget {

  my ($module, $tempDeltaToActivation, $tempDeltaToTarget);
  $module = Test::MockModule->new('HiPi::Interface::DS18X20');

  #It is 20 degrees warm - no need to heat

  $module->mock('temperature', sub { return 20.0 });

  $tempDeltaToTarget = $heater->deltaToTargetTemp();
  is($tempDeltaToTarget, -37, "We are '-37' degrees away to stop heating");
  ok($heater->reachedTargetTemp(), "We have reached our target temperature");

  $tempDeltaToActivation = $heater->deltaToActivationTemp();
  is($tempDeltaToActivation, -40, "We are '-40' degrees away to start heating");
  ok(! $heater->reachedActivationTemp(), "We shouldn't start heating now");


  #It is -30 degrees warm - heat!
  $module->mock('temperature', sub { return -30.0 });

  $tempDeltaToTarget = $heater->deltaToTargetTemp();
  is($tempDeltaToTarget, 13, "We are '13' degrees away to stop heating");
  ok(! $heater->reachedTargetTemp(), "We are far from our target temperature!");

  $tempDeltaToActivation = $heater->deltaToActivationTemp();
  is($tempDeltaToActivation, 10, "We are '10' degrees too cold");
  ok($heater->reachedActivationTemp(), "We should start heating now");


  #It is -18 degrees warm - we are safe but heat a bit, just in case
  $module->mock('temperature', sub { return -18.5 });

  $tempDeltaToTarget = $heater->deltaToTargetTemp();
  is($tempDeltaToTarget, 1.5, "We are '1.5' degrees away to stop heating");
  ok(! $heater->reachedTargetTemp(), "We need a bit more for our target temperature!");

  $tempDeltaToActivation = $heater->deltaToActivationTemp();
  is($tempDeltaToActivation, -1.5, "We are '-1.5' degrees away from heating activation");
  ok(! $heater->reachedActivationTemp(), "We are safe for now");

}



done_testing;
