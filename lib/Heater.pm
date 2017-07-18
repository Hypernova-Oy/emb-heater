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

use Config::Simple;
use HiPi::Interface::DS18X20;
use Sys::Syslog qw(:standard :macros);
use Proc::PID::File;
use Time::HiRes;
use DateTime;
use DateTime::TimeZone;

use GPIO;
use GPIO::Relay::DoubleLatch;

use Heater::Statistics;
use Heater::Config;


use constant {
    NOOP             => 1000,
    TURN_WARMING_ON  => 1001,
    TURN_WARMING_OFF => 1002,
    EMERGENCY_STOP   => 2001,
};


sub new {
    my ($class, $params) = @_;

    my $self = Heater::Config::configure($params);
    bless $self, $class;
    $self->_checkPid();

    $self->{warmerRelay} = GPIO::Relay::DoubleLatch->new(
        $self->{SwitchOnRelayBCMPin},
        $self->{SwitchOffRelayBCMPin});

    $self->{tempSensors} = []; #Prepare to load temp sensors to this data structure
    my $tempSensorIDs = getTemperatureSensorIDs();
    foreach my $id (@$tempSensorIDs) {
        $self->_addTemperatureSensor({id => $id});
    }

    setTimeZone();

    $self->{statistics} = Heater::Statistics->new($self);
    return $self;
}

sub s {
    return $_[0]->{statistics};
}

sub getTemperatureSensorIDs {
    my $oneWireDeviceDir = "/sys/bus/w1/devices";
    opendir(my $dirHandle, $oneWireDeviceDir)
        || exitWithError("Couldn't open OneWire device dir '$oneWireDeviceDir' !");
    my @files = readdir($dirHandle);
    my @tempSensors = grep (/^28.*/, @files);

    if (! scalar @tempSensors) {
        exitWithError("Couldn't find any temperature sensors from '$oneWireDeviceDir' !?");
    }

    return \@tempSensors;
}

sub start {
    my ($self) = @_;

    #Reset the heater relay. This can accidentally be left in the 'On'-position due to running tests or fiddling with gpio outside this program.
    $self->turnWarmingOff();
    my $loopSleep = $self->_getMainLoopSleepDuration();

    while (1) {

        $self->s()->writeStatistics();

        my $hwInstruction = $self->measureState();

        if ($hwInstruction == TURN_WARMING_ON) {
            $self->turnWarmingOn();
        } elsif ($hwInstruction == TURN_WARMING_OFF) {
            $self->turnWarmingOff();
        } elsif ($hwInstruction == EMERGENCY_STOP) {
            $self->turnWarmingOff();
        } elsif ($hwInstruction == NOOP) {
            #Do nothing
        } else {
            die "start():> Unknown hardware instruction '$hwInstruction'";
        }

        Time::HiRes::usleep($loopSleep);
    }
}

=head2 _getMainLoopSleepDuration

@RETURNS Int microseconds

=cut

sub _getMainLoopSleepDuration {
    my ($self) = @_;
    if ($self->{StatisticsWriteInterval}) {
        return $self->{StatisticsWriteInterval}*1000;
    }
    return 5000*1000;
}

=head2 measureState

Does measurements and decides whether to start/stop heating. Returns the hardware instructions.

Separating measurements from hardware actions make it easier to write tests for the heating logic.

=cut

sub measureState {
    my ($self) = @_;

    if ($self->reachedActivationTemp() && not($self->isWarming())) {
        $self->turnWarmingOn();

    } elsif ($self->isWarming() && $self->reachedTargetTemp()) {
        $self->turnWarmingOff();

    }
}

sub reachedTargetTemp {
    my ($self) = @_;
    my $temps = $self->temperatures();
    my $tooCold = 0;
    foreach my $temp (@$temps) {
        $tooCold = 1 if $self->deltaToTargetTemp($temp) >= 0;
    }
    return 1 if (not($tooCold));
}

=head2 deltaToTargetTemp

Calculates how many degrees apart the current temperature and the desired temperature are.
Positive degrees means we must get more heating to reach safe temperatures.
Negative degrees means we can endure that much cooling.

=cut

sub deltaToTargetTemp {
    my ($self, $tempReading) = @_;
    return _tempDelta($self->{TargetTemperature}, $tempReading);
}

=head2 reachedActivationTemp

@RETURNS Boolean, true if any sensor reaches this threshold

=cut

sub reachedActivationTemp {
    my ($self) = @_;
    my $temps = $self->temperatures();
    foreach my $temp (@$temps) {
        return 1 if $self->deltaToActivationTemp($temp) >= 0;
    }
}

=head2 deltaToActivationTemp

Calculates how many degrees apart the current temperature and the minimum allowed temperature are.
Positive degrees means we must get more heating to reach safe temperatures.
Negative degrees means we can endure that much cooling.

=cut

sub deltaToActivationTemp {
    my ($self, $tempReading) = @_;
    return _tempDelta($self->{ActivationTemperature}, $tempReading);
}

sub _tempDelta {
    return ($_[0]+1000) - ($_[1]+1000);
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
    my $withQuantum = $_[1];
    my $sensors = $_[0]->getTemperatureSensors();
    my @temps;
    foreach my $sensor (@$sensors) {
        my $t = $sensor->temperature();
        warn "Sensor '$id' reading '$t' exceeds printable column size '$tempReadingColWidth', increase it!" if (length $t > $tempReadingColWidth);
        push(@temps, ($withQuantum) ? $sensor->temperature().'℃' : $sensor->temperature());
    }
    return \@temps;
}

sub _addTemperatureSensor {
    my ($self, $params) = @_;
    my $id;
    eval { $id = $params->{id}; };
    die ref($self)."->_addTemperatureSensor($params):> \$params->{id} is not defined! $@" unless $id;

    foreach my $sens (@{$self->{tempSensors}}) {
        warn "_addTemperatureSensor():> Device '$id' already added?" if ($sens->{id} eq $id);
    }

    push ( @{$self->{tempSensors}},
        HiPi::Interface::DS18X20->new(
            id         => $id,
            correction => $self->{TemperatureCorrection},
            divider    => 1000,
    );
}
sub getTemperatureSensors {
    return $_[0]->{tempSensors};
}

=head2 _checkPid

Checks if this daemon is already listening to the given pins.
If a daemon is using these pins, the existing daemon is killed and this
daemon is started.

TODO:: Duplicates emb-rtttl PID-mechanism

=cut

sub _checkPid {
    my ($self) = @_;

    $self->{pid} = getPid($self);
    _killExistingProgram($self->{pid}) if $self->{pid}->alive();
    $self->{pid}->touch();
}

=head2 killHeater

A static method for killing a Heater-daemon matching the given configuration.

=cut

sub killHeater {
    my ($conf) = @_;
    _killExistingProgram(getPid($conf));
}

=head2 getPid

A static method to get the Proc::PID::File of this daemon from the given config.

=cut

sub getPid {
    my ($conf) = @_;
    my $name = _makePidFileName($conf->{SwitchOnRelayBCMPin},
                                $conf->{SwitchOffRelayBCMPin},
    );
    return Proc::PID::File->new({name => $name,
                                 verify => $name,
                                }
    );
}

sub _killExistingProgram {
    my ($pid) = @_;
    kill 'INT', $pid->read();
}

sub _makePidFileName {
    my (@pins) = @_;
    return join('-',__PACKAGE__,@pins);
}

1;
