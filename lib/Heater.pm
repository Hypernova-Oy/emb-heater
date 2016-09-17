#!/usr/bin/perl
#
# Copyright (C) 2016 Koha-Suomi
#
# This file is part of emb-heater.
#
# emb-heater is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# emb-heater is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with emb-heater.  If not, see <http://www.gnu.org/licenses/>.

package Heater;

our $VERSION = "0.01";

use Modern::Perl;
use Config::Simple;
use HiPi::Interface::DS18X20;
use Sys::Syslog qw(:standard :macros);

use GPIO;
use Relay::DoubleLatch;


my $configFile = "/etc/emb-heater/daemon.conf";



sub new {
    my ($class, $params) = @_;

    my $self = mergeConfig($params);
    bless $self, $class;

    $self->{warmerRelay} = Relay::DoubleLatch->new(
        $self->{SwitchOnRelayBCMPin},
        $self->{SwitchOffRelayBCMPin});

    $self->_setTemperatureSensor(
        HiPi::Interface::DS18X20->new(
            id         => getTemperatureSensorID(),
            correction => $self->{TemperatureCorrection},
            divider    => 1000,
        )
    );

}

sub getTemperatureSensorID {
    opendir(my $dirHandle, "/sys/bus/w1/devices")
	|| exitWithError("Couldn't open temperature sensor dir");
    my @files = readdir($dirHandle);
    my @tempSensors = grep (/^28.*/, @files);

    if (! scalar @tempSensors) {
	exitWithError("Couldn't connect to a temperature sensor");
    }

    return $tempSensors[0];
}

sub start {
    my ($self) = @_;
    $self->{warmingIsOn} = 0;

    while (1) {
	if ($self->reachedActivationTemp() && !$self->{warmingIsOn}) {
	    $self->turnWarmingOn();
	} elsif ($self->{warmingIsOn} && $self->reachedTargetTemp()) {
	    $self->turnWarmingOff();
	}

	sleep 1;
    }
}

sub reachedTargetTemp {
    my ($self) = @_;
    return 1 if $self->deltaToTargetTemp() <= 0;
}

=head2 deltaToTargetTemp

Calculates how many degrees apart the current temperature and the desired temperature are.
Positive degrees means we must get more heating to reach safe temperatures.
Negative degrees means we can endure that much cooling.

=cut

sub deltaToTargetTemp {
    my ($self) = @_;
    my $temperature = $self->getTemperatureSensor()->temperature();
    my $targetTemp = $self->{TargetTemperature};
    return ($targetTemp+1000) - ($temperature+1000);
}

sub turnWarmingOn {
    my ($self) = @_;
    $self->{warmerRelay}->switchOn();
    $self->{warmingIsOn} = 1;
    return $self;
}

sub turnWarmingOff {
    my ($self) = @_;
    $self->{warmerRelay}->switchOff();
    $self->{warmingIsOn} = 0;
    return $self;
}

sub reachedActivationTemp {
    my ($self) = @_;
    return 1 if $self->deltaToActivationTemp() >= 0;
}

=head2 deltaToActivationTemp

Calculates how many degrees apart the current temperature and the minimum temperature are.
Positive degrees means we must get more heating to reach safe temperatures.
Negative degrees means we can endure that much cooling.

=cut

sub deltaToActivationTemp {
    my ($self) = @_;
    my $temperature = $self->getTemperatureSensor()->temperature();
    my $targetTemp = $self->{ActivationTemperature};
    return ($targetTemp+1000) - ($temperature+1000);
}

sub exitWithError {
    my ($error) = @_;
    syslog(LOG_ERR, $error);
    say $error;
    exit(1);
}

sub getTemperatureSensor {
    return $_[0]->{tempSensor};
}
sub _setTemperatureSensor {
    $_[0]->{tempSensor} = $_[1];
    return $_[0];
}

=head2 mergeConfig

Take user parameters and system configuration and override with user parameters.
Validate config.

=cut

sub mergeConfig {
    my ($params) = @_;

    my $config = getConfig();
    while( my ($k,$v) = each(%$params) ) {
        $config->{$k} = $params->{$k};
    }
    isConfigValid($config);
    return $config;
}

=head2

Get config and remove strange default-block

=cut

sub getConfig {
    my $c = new Config::Simple($configFile)
	|| exitWithError(Config::Simple->error());
    $c = $c->vars();
    my %c;
    while (my ($k,$v) = each(%$c)) {
        my $newKey = $k;
        $newKey =~ s/^default\.//;
        $c{$newKey} = $c->{$k};
    }
    return \%c;
}


my $signed_float_regexp = '-?\d+\.?\d*';
my $signed_int_regexp = '-?\d+';
my $unsigned_int_regexp = '\d+';
sub isConfigValid() {
    my ($c) = @_;

    unless ($c->{ActivationTemperature} && $c->{ActivationTemperature} =~ /^$signed_float_regexp$/) {
        exitWithError("ActivationTemperature is not a valid signed float");
    }
    unless ($c->{TargetTemperature} && $c->{TargetTemperature} =~ /^$signed_float_regexp$/) {
        exitWithError("TargetTemperature is not a valid signed float");
    }
    unless ($c->{TemperatureCorrection} && $c->{TemperatureCorrection} =~ /^$signed_int_regexp$/) {
        exitWithError("TemperatureCorrection is not a valid signed int");
    }
    unless ($c->{SwitchOnRelayBCMPin} && $c->{SwitchOnRelayBCMPin} =~ /^$unsigned_int_regexp$/) {
        exitWithError("SwitchOnRelayBCMPin is not a valid unsigned int");
    }
    unless ($c->{SwitchOffRelayBCMPin} && $c->{SwitchOffRelayBCMPin} =~ /^$unsigned_int_regexp$/) {
        exitWithError("SwitchOffRelayBCMPin is not a valid unsigned int");
    }
    unless ($c->{StatisticsWriteInterval} &&
               ($c->{StatisticsWriteInterval} =~ /^$unsigned_int_regexp$/ ||
                $c->{StatisticsWriteInterval} < 0
               )
           ) {
        exitWithError("StatisticsWriteInterval is not a valid unsigned int");
    }

    return 1;
}

