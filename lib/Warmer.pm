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

package Warmer;

our $VERSION = "0.01";

use Modern::Perl;
use Config::Simple;
use HiPi::Interface::DS18X20;
use Sys::Syslog qw(:standard :macros);

use GPIO;
use Relay::DoubleLatch;

# GPIO pins from emb-toveri schematics
use constant {
    SWITCH_ON_RELAY_GPIO => 23,
    SWITCH_ON_RELAY_GPIO => 24,
};

sub new {
    my ($class,
	$switchOnRelayGPIO,
	$switchOffRelayGPIO,
	$activationTemp,
	$targetTemp) = @_;

    my $self = {};

    $self->{switchOnRelayGPIO} = $switchOnRelayGPIO;
    $self->{switchOffRelayGPIO} = $switchOffRelayGPIO;

    $self->{activationTemp} = $activationTemp;
    $self->{targetTemp} = $targetTemp;

    $self->{warmerRelay} = Relay::DoubleLatch->new(
	$self->{switchOnRelayGPIO},
	$self->{switchOffRelayGPIO});

    $self->{tempSensor} = HiPi::Interface::DS18X20->new(
	id         => getTemperatureSensorID(),
	correction => -100,
	divider    => 1000,
	);

    bless $self, $class;
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
	if ($self->isActivationTemp() && !$self->{warmingIsOn}) {
	    $self->turnWarmingOn();
	} elsif ($self->{warmingIsOn} && $self->reachedTargetTemp()) {
	    $self->turnWarmingOff();
	}

	sleep 1;
    }
}

sub reachedTargetTemp {
    my ($self) = @_;
    my $temperature = $self->{tempSensor}->temperature();
    my $targetTemp = $self->{targetTemp};
    return $temperature >= $targetTemp;
}

sub turnWarmingOn {
    my ($self) = @_;
    $self->{warmerRelay}->switchOn();
    $self->{warmingIsOn} = 1;
}

sub turnWarmingOff {
    my ($self) = @_;
    $self->{warmerRelay}->switchOff();
    $self->{warmingIsOn} = 0;
}

sub isActivationTemp {
    my ($self) = @_;
    my $temperature = $self->{tempSensor}->temperature();
    my $activationTemp = $self->{activationTemp};
    return $temperature < $activationTemp;
}

sub exitWithError {
    my ($error) = @_;
    syslog(LOG_ERR, $error);
    say $error;
    exit(1);
}

sub getConfig {
    my $configFile = "/etc/emb-heater/daemon.conf";
    my $config = new Config::Simple($configFile)
	|| exitWithError(Config::Simple->error());
    return $config;
}

sub isConfigValid() {
    my @params = ("ActivationTemperature",
		  "TargetTemperature");

    foreach my $param (@params) {
	if (!getConfig()->param($param)) {
	    say "$param not defined in daemon.conf";
	    return 0;
	} elsif (!($param =~ /-?\d+/)) {
	    say("$param value is invalid. ",
		"Valid value is an integer.");
	    return 0;
	}
    }

    return 1;
}

sub main {

    my $activationTemp = getConfig()->param('ActivationTemperature');
    my $targetTemp = getConfig()->param('TargetTemperature');

    my $warmer = Warmer->new(SWITCH_ON_RELAY_GPIO,
			     SWITCH_ON_RELAY_GPIO,
			     $activationTemp,
			     $targetTemp);

    $warmer->start();
}

main();
