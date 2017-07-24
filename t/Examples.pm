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

package t::Examples;

#Pragmas
use Modern::Perl;

#Global modules


#Local modules
use Heater;

sub getDefaultConf {
    return {
        SwitchOnRelayBCMPin => 23,
        SwitchOffRelayBCMPin => 24,
        ActivationTemperature => -20,
        TargetTemperature => -17,
        TemperatureCorrection => 100,
        StatisticsWriteInterval => -1,
        EmergencyShutdownTemperature => 85,
        EmergencyPassedTemperature => 70,
    };
}

sub getHeater {
    my ($conf) = @_;
    $conf = getDefaultConf() unless $conf;
    return Heater->new($conf);
}

sub getStatisticalConf {
    my $conf = getDefaultConf();
    $conf->{StatisticsWriteInterval} = 300;
    $conf->{StatisticsLogFile} = ''; #this cannot be empty. Create a path before starting the daemon
    return $conf;
}

sub getDaemonizingCommand {
    my ($conf) = @_;
    return join(' ',
            'perl -Ilib scripts/heater',
            '--on', $conf->{SwitchOnRelayBCMPin},
            '--off',$conf->{SwitchOffRelayBCMPin},
            '-s',   $conf->{StatisticsWriteInterval},
            '-sf',  $conf->{StatisticsLogFile},
        );
}


1;
