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

=head2 nextStateTransition

Does measurements and decides whether to start/stop heating. Returns the new state to transition to.

Separating measurements from hardware actions make it easier to write tests for the heating logic.

@RETURNS 0 if there is no need to transition

=cut

sub nextStateTransition {
    my ($h) = @_;
    my $currentState = $h->state->name;

    if ($currentState eq $Heater::STATE_EMERGENCY_SHUTDOWN) {
        if (_reachedEmergencyPassedTemp($h)) {
            return $Heater::STATE_IDLE;
        }
        else {
            return 0; #Only way to transition away from the emergency shutdown is via _reachedEmergencyPassedTemp()
        }
    }

    if (_reachedEmergencyShutdownTemp($h)) {
      return $Heater::STATE_EMERGENCY_SHUTDOWN;
    }
    if (_reachedTargetTemp($h)) {
        return $Heater::STATE_IDLE;
    }
    if (_reachedActivationTemp($h)) {
        return $Heater::STATE_WARMING;
    }
    return 0;

    #else {
    #    Heater::Exception::UnknownStateTransition->throw(error => "Couldn't decide the next state transition.", previousState => $h->state->name);
    #}
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
        if (_tempDelta($h->{TargetTemperature}, $temp) > 0) {
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
        return 1 if (_tempDelta($h->{ActivationTemperature}, $temp) >= 0);
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
        return 1 if (_tempDelta($self->{EmergencyShutdownTemperature}, $temp) <= 0);
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
        return 0 if (_tempDelta($self->{EmergencyPassedTemperature}, $temp) < 0);
    }
    return 1;
}

sub _tempDelta {
    #Really just param1 - param2, simply using +1000 to solve floating number rounding problems
    return ($_[0]+1000) - ($_[1]+1000);
}

1;
