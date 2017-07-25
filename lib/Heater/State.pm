#!/usr/bin/perl
#
# Copyright (C) 2017 Koha-Suomi
#
# This file is part of emb-heater.
#
# emb-heater is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

package Heater::State;

our $VERSION = "0.01";

use Modern::Perl;
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

use Param::Validate;
use DateTime;

use HeLog;
my $l = bless({}, 'HeLog');


use Heater::Exception::UnknownState;
use Heater::Exception::Hardware::HeatingElement;


my %validations_new = (
  startingTemps => { callbacks => { 'arrayOfFloats' => sub {
    if (ref($_[0]) eq 'ARRAY') {
        foreach my $f (@$_[0]) {
            return 0 unless $f =~ /^-?\d+\.?\d*$/;
        }
    }
    return 0;
  } },},
  name          => { optional => 0 },
  heater        => { isa => 'Heater'},
  ticks         => { optional => 1 },
  timestamp     => { optional => 1 },
);
sub new {
    my ($class, $params) = @_;
    Params::Validate::validate($params, \%validations_new);

    my $self = {heater => $params->{heater}};
    weaken($self->{heater}); #Avoid circular referencing, which causes memory leaks
    bless $self, $class;

    $self->{ticks} = $params->{ticks} || 0;
    $self->{started} = $params->{timestamp} || time;
    $self->{startingTemps} = $params->{startingTemps};

    return $self;
}

sub h {
    return $_[0]->{heater};
}

sub tick {
    my ($self) = @_;

    my $stateName = $self->name();

    if ($stateName eq $Heater::STATE_IDLE) {
        $self->h->turnWarmingOff() if ($self->h->isWarming());
    }
    elsif ($stateName eq $Heater::STATE_WARMING) {
        $self->h->turnWarmingOn() if (!$self->h->isWarming());
        $self->checkTempHasRisen();
    }
    elsif ($stateName eq $Heater::STATE_EMERGENCY_SHUTDOWN) {
        $self->h->turnWarmingOff() if ($self->h->isWarming());
    }
    else {
        Heater::Exception::UnknownState->throw(state => $stateName);
    }

    $self->{ticks}++;
    return $self;
}

sub name {
    return shift->{name};
}
sub ticks {
    return shift->{ticks};
}

=head2 started

@RETURNS Unix timestamp when this state was started

=cut

sub started {
    return shift->{started};
}
sub setStarted {
    shift->{started} = shift;
}

sub startingTemperatures {
    return shift->{startingTemps};
}

sub checkTempHasRisen {
    my ($self) = @_;
    my $heatingDuration = time - $self->started;

    #If Heater has been heating for more than 60 seconds, check that the temperature has significantly risen since the start of heating.
    return undef unless ($heatingDuration > 60);

    my $mhe = $self->h->{MinimumHeatingEfficiency};
    my $expectedTempRise = $mhe * $heatingDuration/60;
    my $newTemps = $self->h->temperatures();
    my $oldTemps = $self->startingTemperatures();

    my $anySensorRegistersMinimumTemperatureRise = 0;
    my $biggestMeasuredTempRise;
    for (my $i=0 ; $i<scalar(@$oldTemps) ; $i++) {
        #If the expected minimum temperature rise is higher than the actual measured temperature, hardware is dysfunctional.
        $anySensorRegistersMinimumTemperatureRise = 1 if (($oldTemps->[$i] + $expectedTempRise) <= $newTemps->[$i]);
        $biggestMeasuredTempRise = $oldTemps->[$i] - $newTemps->[$i] if (not(defined($biggestMeasuredTempRise)) || ($oldTemps->[$i] - $newTemps->[$i]) > $biggestMeasuredTempRise);
    }
    Heater::Exception::Hardware::HeatingElement->throw(
            error => "Heater isn't performing as expected",
            expectedTemperatureRise => $expectedTempRise,
            biggestMeasuredTemperatureRise => $biggestMeasuredTempRise,
            heatingDuration => $heatingDuration,
    ) unless $anySensorRegistersMinimumTemperatureRise;
}

1;
