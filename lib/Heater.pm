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
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';
use Try::Tiny;
use Scalar::Util qw(blessed);
use Storable;

use Config::Simple;
use HiPi::Interface::DS18X20;
use Proc::PID::File;
use Time::HiRes;
use DateTime;
use DateTime::TimeZone;

use GPIO;
use GPIO::Relay::DoubleLatch;

use Heater::Statistics;
use Heater::Config;
use Heater::Transitions;
use Heater::Pid;
use Heater::State;

use HeLog;
my $l = bless({}, 'HeLog');

use Heater::Exception::Hardware::TemperatureSensor;

our $STATE_WARMING            = 'W';
our $STATE_IDLE               = 'I';
our $STATE_EMERGENCY_SHUTDOWN = 'E';


=head1 SYNOPSIS

A Relay-controlled Heater with multiple temperature sensors.
Operates autonomously, trying to keep the temperature readings of temperature sensors between nominal operational temperatures.

See doc/Heater.png for the Heater's internal states activity diagram. .uxf is the source Umlet-file

=cut


sub new {
    my ($class, $params) = @_;

    my $self = Heater::Config::configure($params);
    bless $self, $class;
    Heater::Pid::checkPid($self);

    $self->{warmerRelay} = GPIO::Relay::DoubleLatch->new(
        Heater::Config::getSwitchOnRelayBCMPin($self),
        Heater::Config::getSwitchOffRelayBCMPin($self),
    );

    $self->{tempSensors} = []; #Prepare to load temp sensors to this data structure

    my @tempSensorDevices = HiPi::Interface::DS18X20->list_slaves();
    $l->logdie(Heater::Exception::toText(Heater::Exception::Hardware::TemperatureSensor->throw(error => "No DS18X20-compatible temperature sensors detected on the one wire bus. Have you enabled the one-wire hardware device?")))
        unless scalar(@tempSensorDevices);

    foreach my $device (@tempSensorDevices) {
        $self->_addTemperatureSensor($device);
    }

    $self->{statistics} = Heater::Statistics->new($self);

    #Reset the heater relay. This can accidentally be left in the 'On'-position due to running tests or fiddling with gpio outside this program.
    $l->info("Turning off heater just in case");
    $self->turnWarmingOff();
    $self->setState($STATE_IDLE);

    return $self;
}

sub s {
    return shift->{statistics};
}

sub state {
    return shift->{state};
}

#@DEPRECATED - preserved as useful documentation about where one-wire devices are in the system
sub getTemperatureSensorIDs {
    my $oneWireDeviceDir = "/sys/bus/w1/devices";
    opendir(my $dirHandle, $oneWireDeviceDir)
        || die("Couldn't open OneWire device dir '$oneWireDeviceDir' !");
    my @files = readdir($dirHandle);
    my @tempSensors = grep (/^28.*/, @files);

    if (! scalar @tempSensors) {
        die("Couldn't find any temperature sensors from '$oneWireDeviceDir' !?");
    }

    return \@tempSensors;
}

sub start {
    my ($self) = @_;


    my $loopSleep = $self->_getMainLoopSleepDuration();

    try {
        while (1) {
            $self->mainLoop();

            $l->trace("Sleeping '".($loopSleep/1000000)."s' after mainLoop()");
            Time::HiRes::usleep($loopSleep);
        }
    } catch {
        $l->fatal("Main loop crashed with error: ".Heater::Exception::toText($_));
        $l->info("Turning off heater");
        $self->turnWarmingOff();
        die $_ unless (blessed($_));
        $_->rethrow();
    };
}

sub mainLoop {
    my ($self) = @_;
    $l->debug("Starting mainLoop()");

    $self->flushTemperaturesCache();

    my $nextStateName = Heater::Transitions::nextStateTransition($self);
    $self->setState($nextStateName) if $nextStateName;

    $self->enforceState();

    $self->s()->writeStatistics() if $self->_isTimeToWriteStatistics();
}

=head2 enforceState

Makes sure the hardware is set to the correct state.

=cut

sub enforceState {
    my ($self) = @_;

    $self->state->tick;
}

=head3 _getMainLoopSleepDuration

@RETURNS Int microseconds

=cut

sub _getMainLoopSleepDuration {
    my ($self) = @_;
    return Heater::Config::getMainLoopInterval($self)*1000;
}

=head3 _isTimeToWriteStatistics

Checks if StatisticsWriteInterval-amount of seconds has passed since the last time
statistics were written.

@RETURNS Boolean, true if now is time to write statistics

=cut

sub _isTimeToWriteStatistics {
    my ($self) = @_;
    unless ($self->{_statsWrittenTime}) {
        $self->{_statsWrittenTime} = time unless $self->{_statsWrittenTime};
        $l->debug("Initialized the time statistics were last written");
    }

    my $timeToWriteStatistics = $self->{_statsWrittenTime} + Heater::Config::getStatisticsWriteInterval($self) - time;
    $l->trace("\$timeToWriteStatistics => '$timeToWriteStatistics'");
    if ($timeToWriteStatistics <= 0) {
        $self->{_statsWrittenTime} = time;
        return 1;
    }
    return 0;
}

sub turnWarmingOn {
    my ($self) = @_;
    $l->info("Turning warming on using BCM pin '".Heater::Config::getSwitchOnRelayBCMPin($self)."'");
    $self->{warmerRelay}->switchOn() if (not($ENV{HEATER_TEST_MODE}));
    $self->{warmingIsOn} = 1;
    return $self;
}

sub turnWarmingOff {
    my ($self) = @_;
    $l->info("Turning warming off using BCM pin '".Heater::Config::getSwitchOffRelayBCMPin($self)."'");
    $self->{warmerRelay}->switchOff() if (not($ENV{HEATER_TEST_MODE}));
    $self->{warmingIsOn} = 0;
    return $self;
}

sub isWarming {
    return shift->{warmingIsOn};
}

=head2 temperatures

@PARAM1 Boolean, append the quantum sigil '℃' after the temperature reading?
@RETURNS List of doubles, list of temperatures of all registered temperature sensors
             eg. [-9.725, -12.12]
             eg. [-9.725℃, -12.12℃]

=cut

sub temperatures {
    my ($self, $withQuantum) = @_;
    my $sensors = $self->getTemperatureSensors();
    my $temps = $self->getCachedTemperaturesReading();

    unless ($temps) {
        $temps = [];
        foreach my $sensor (@$sensors) {
            my $t = $sensor->temperature();
            Heater::Exception::Hardware::TemperatureSensor->throw(error => "Unknown temperature sensor reading", sensorId => $sensor->id()) unless(defined($t));
            push(@$temps, $t);
        }
        $self->cacheTemperaturesReading($temps);
    }

    @$temps = map {$_.'℃'}  @$temps if $withQuantum;

    unless (scalar(@$sensors) == $_[0]->{TemperatureSensorsCount}) {
        Heater::Exception::Hardware->throw(error => "Expected to have '".Heater::Config::getTemperatureSensorsCount($self)."' temperature sensors, but found only '".scalar(@$sensors)."'");
    }

    return $temps;
}

sub _addTemperatureSensor {
    my ($self, $params) = @_;
    $l->info("Adding temperature sensor: ".$l->flatten($params));

    my $id;
    eval { $id = $params->{id}; };
    die ref($self)."->_addTemperatureSensor($params):> \$params->{id} is not defined! $@" unless $id;

    foreach my $sens (@{$self->{tempSensors}}) {
        warn "_addTemperatureSensor():> Device '$id' already added?" if ($sens->id eq $id);
    }

    push ( @{$self->{tempSensors}},
        HiPi::Interface::DS18X20->new(
            id         => $id,
            correction => Heater::Config::getTemperatureCorrection($self),
            divider    => 1000,
        )
    );
}
sub getTemperatureSensors {
    return $_[0]->{tempSensors};
}

=head2 cacheTemperaturesReading

Reading the temperature is slow, and can possibly cause the i2c channel to freeze if using long
cables and there is a bit transmission error.
So we cache the result to avoid unnecessary communication.

=cut

sub cacheTemperaturesReading {
    my ($self, $readings) = @_;
    my $deepCopy = Storable::dclone($readings); #Make a deep copy, to separate dependencies between other program modules requiring the cached object.
    $self->{_tempCache} = [Time::HiRes::time*1000, $deepCopy]; #Caching time in millis
    $l->trace("Cached temperature readings '@$readings'");
}

=head2 flushTemperaturesCache

Clear the temperature cache, so a new value can be fetched.

=cut

sub flushTemperaturesCache {
    shift->{_tempCache} = undef;
}

=head2 getCachedTemperaturesReading

Returns the cached value, or undef.
Checks for cache expiration, and expires expired cache record.

=cut

sub getCachedTemperaturesReading {
    my ($self) = @_;
    my $cacheExpiration = 1000; #milliseconds
    if (my $c = $self->{_tempCache}) {
        if ($c->[0] + $cacheExpiration < Time::HiRes::time*1000) {
            $l->trace("Cached temperature readings expired");
            $self->flushTemperaturesCache();
            return undef;
        }
        return Storable::dclone($c->[1]);
    }
    else {
        $l->trace("Temperature cache miss");
    }
    return undef;
}

=head2 setState

=cut

sub setState {
    my ($self, $stateName) = @_;
    if (not($self->state) || $self->state->name ne $stateName) {
        $self->{state} = Heater::State->new({
            heater => $self,
            name => $stateName,
            startingTemps => $self->temperatures(),
        });
        $self->s()->writeStatistics(); #Write statistics to show the state has transitioned.
    }
}

1;
