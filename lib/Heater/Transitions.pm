#!/usr/bin/perl
#
# Copyright (C) 2017 Koha-Suomi
#
# This file is part of emb-heater.
#

package Heater::Transitions;

our $VERSION = "0.01";

use Modern::Perl;
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';
use Try::Tiny;
use Scalar::Util qw(blessed);

use Heater::Exception::UnknownStateTransition;

#use Heater; #This package is loaded from Heater and cannot be used standalone, resist the urge of unnecessary include-directives to avoid circular dependency loading issues.

use HeLog;
my $l = bless({}, 'HeLog');



=head1 SYNOPSIS

This is a static extension class to Heater.pm

This encapsulates all state transition logic.

=cut


## Save calculated deltas here, used mainly for testing the subroutines did what was expected.
## Don't write to them directly!!
our $deltaToTargetTemperature;
our $deltaToActivationTemperature;
our $deltaToEmergencyShutdownTemperature;
our $deltaToEmergencyPassedTemperature;

=head2 nextStateTransition

Does measurements and decides whether to start/stop heating. Returns the new state to transition to.

Separating measurements from hardware actions make it easier to write tests for the heating logic.

@RETURNS 0 if there is no need to transition

=cut

sub nextStateTransition {
    my ($h) = @_;
    my $currentState = $h->state->name;
    my $newState;

    if ($currentState eq $Heater::STATE_EMERGENCY_SHUTDOWN) {
        if (_reachedEmergencyPassedTemp($h)) {
            $newState = $Heater::STATE_IDLE;
        }
        else {
            $newState = 0; #Only way to transition away from the emergency shutdown is via _reachedEmergencyPassedTemp()
        }
    }

    elsif (_reachedEmergencyShutdownTemp($h)) {
        $newState = $Heater::STATE_EMERGENCY_SHUTDOWN;
    }
    elsif (_reachedTargetTemp($h)) {
        $newState = $Heater::STATE_IDLE;
    }
    elsif (_reachedActivationTemp($h)) {
        $newState = $Heater::STATE_WARMING;
    }
    #else {
    #    Heater::Exception::UnknownStateTransition->throw(error => "Couldn't decide the next state transition.", previousState => $h->state->name);
    #}
    $newState = 0 unless(defined($newState));

    $l->debug("Next state transition is '$newState'");
    return $newState;
}

=head2 _reachedTargetTemp

All sensors must have reached the minimum temperature

@RETURNS Boolean, True if Heater has heated enough

=cut

sub _reachedTargetTemp {
    my ($h) = @_;
    my $temps = $h->temperatures();
    foreach my $temp (@$temps) {

        #Calculates how many degrees apart the current temperature and the desired temperature are.
        #Positive degrees means we must get more heating to reach safe temperatures.
        #Negative degrees means we can endure that much cooling.
        $deltaToTargetTemperature = _tempDelta($h->{TargetTemperature}, $temp);
        $l->trace("\$deltaToTargetTemperature => '".sprintf("%7.3f",$deltaToTargetTemperature)."'");
        if ($deltaToTargetTemperature > 0) {
            return 0; #More heating is needed!
        }
    }
    return 1; #All sensors are above the target temperature
}

=head2 _reachedActivationTemp

Any sensor can say that it is too cold

@RETURNS Boolean, true if any sensor reaches this threshold to start heating

=cut

sub _reachedActivationTemp {
    my ($h) = @_;
    my $temps = $h->temperatures();
    foreach my $temp (@$temps) {

        #Calculates how many degrees apart the current temperature and the minimum allowed temperature are.
        #Positive degrees means we must get more heating to reach safe temperatures.
        #Negative degrees means we can endure that much cooling.
        $deltaToActivationTemperature = _tempDelta($h->{ActivationTemperature}, $temp);
        $l->trace("\$deltaToActivationTemperature => '".sprintf("%7.3f",$deltaToActivationTemperature)."'");
        return 1 if ($deltaToActivationTemperature >= 0);
    }
    return 0;
}

=head2 _reachedEmergencyShutdownTemp

Any sensor can say that it has had enough

@RETURNS Boolean, true if any sensor reaches this threshold to stop heating

=cut

sub _reachedEmergencyShutdownTemp {
    my ($self) = @_;
    my $temps = $self->temperatures();
    foreach my $temp (@$temps) {
        #Return if temperature is higher or equal than the given threshold
        $deltaToEmergencyShutdownTemperature = _tempDelta($self->{EmergencyShutdownTemperature}, $temp);
        $l->trace("\$deltaToEmergencyShutdownTemperature => '".sprintf("%7.3f",$deltaToEmergencyShutdownTemperature)."'");
        return 1 if ($deltaToEmergencyShutdownTemperature <= 0);
    }
    return 0;
}

=head2 _reachedEmergencyPassedTemp

All sensors must have passed the emergency passed threshold

@RETURNS Boolean, true if all sensors reach this threshold to pass the emergency

=cut

sub _reachedEmergencyPassedTemp {
    my ($self) = @_;
    my $temps = $self->temperatures();
    foreach my $temp (@$temps) {
        #Return if temperature is higher than the given threshold
        $deltaToEmergencyPassedTemperature = _tempDelta($self->{EmergencyPassedTemperature}, $temp);
        $l->trace("\$deltaToEmergencyPassedTemperature => '".sprintf("%7.3f",$deltaToEmergencyPassedTemperature)."'");
        return 0 if ($deltaToEmergencyPassedTemperature < 0);
    }
    return 1;
}

sub _tempDelta {
    #Really just param1 - param2, simply using +1000 to solve floating number rounding problems
    return ($_[0]+1000) - ($_[1]+1000);
}

1;
