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
#

package Heater::Config;

our $VERSION = "0.01";

use Modern::Perl;
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';
use Carp qw(longmess);

use Config::Simple;
use DateTime::TimeZone;

#use HeLog; #We cannot use Log::Log4perl here, because the configuration hasn't been validated yet. Configuration controls logging. Die on errors instead.
my $l = bless({}, 'HeLog');

my $configFile = "/etc/emb-heater/daemon.conf";

=head2 configure

Configures the whole program

@RETURNS HASHRef with configuration values

=cut

my $olConfig;
sub configure {
    my ($params) = @_;

    $olConfig = _mergeConfig($params);
    #Global config is set here. After this point logger can be used in this package.
    $l->debug("Using configurations: ".$l->flatten($olConfig));

    my $tz = setTimeZone();
    $l->debug("Using time zone: $tz");

    return $olConfig;
}

=head2 mergeConfig

Take user parameters and system configuration and override with user parameters.
Validate config.

=cut

sub _mergeConfig {
    my ($params) = @_;
    $l->debug("Received following configuration overrides: ".$l->flatten($params)) if $params;

    my $config = _slurpConfig();

    #Merge params to config
    if(ref($params) eq 'HASH') {
        while( my ($k,$v) = each(%$params) ) {
            $config->{$k} = $params->{$k};
        }
    }

    _isConfigValid($config);
    return $config;
}

sub _slurpConfig {
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

=head2

Get config and remove strange default-block

=cut

sub getConfig {
    return $olConfig if $olConfig;
    return configure();
}


my $signed_float_regexp = '-?\d+\.?\d*';
my $signed_int_regexp = '-?\d+';
my $unsigned_int_regexp = '\d+';
sub _isConfigValid() {
    my ($c) = @_;

    unless ($c->{ActivationTemperature} && $c->{ActivationTemperature} =~ /^$signed_float_regexp$/) {
        die("ActivationTemperature is not a valid signed float");
    }
    unless ($c->{TargetTemperature} && $c->{TargetTemperature} =~ /^$signed_float_regexp$/) {
        die("TargetTemperature is not a valid signed float");
    }
    unless ($c->{TemperatureCorrection} && $c->{TemperatureCorrection} =~ /^$signed_int_regexp$/) {
        die("TemperatureCorrection is not a valid signed int");
    }
    unless ($c->{SwitchOnRelayBCMPin} && $c->{SwitchOnRelayBCMPin} =~ /^$unsigned_int_regexp$/) {
        die("SwitchOnRelayBCMPin is not a valid unsigned int");
    }
    unless ($c->{SwitchOffRelayBCMPin} && $c->{SwitchOffRelayBCMPin} =~ /^$unsigned_int_regexp$/) {
        die("SwitchOffRelayBCMPin is not a valid unsigned int");
    }
    unless ($c->{StatisticsWriteInterval} &&
               ($c->{StatisticsWriteInterval} =~ /^$unsigned_int_regexp$/ ||
                $c->{StatisticsWriteInterval} < 0
               )
           ) {
        die("StatisticsWriteInterval is not a valid signed int");
    }
    if ($c->{StatisticsWriteInterval}) {
        unless(  $c->{StatisticsLogFile} && $c->{StatisticsLogFile} =~ /^.+$/  ) {
            die("StatisticsLogFile must be a valid path if StatisticsWriteInterval is defined");
        }
    }
    unless ($c->{EmergencyShutdownTemperature} && $c->{EmergencyShutdownTemperature} =~ /^$signed_int_regexp$/) {
        die("EmergencyShutdownTemperature is not a valid signed int");
    }
    if ($c->{EmergencyShutdownTemperature} > 85) {
        die("EmergencyShutdownTemperature is more than the allowed safe limit of 85 degrees celsius");
    }
    unless ($c->{EmergencyPassedTemperature} && $c->{EmergencyPassedTemperature} =~ /^$signed_int_regexp$/) {
        die("EmergencyPassedTemperature is not a valid signed int");
    }
    unless ($c->{TemperatureSensorsCount} && $c->{TemperatureSensorsCount} =~ /^$unsigned_int_regexp$/) {
        die("TemperatureSensorsCount is not a valid unsigned int");
    }
    unless ($c->{MinimumHeatingEfficiency} && $c->{MinimumHeatingEfficiency} =~ /^$unsigned_int_regexp$/) {
        die("MinimumHeatingEfficiency is not a valid unsigned int");
    }

    return 1;
}

=head2 makeConfig

Make a configuration HASH from an ordered set of values.
This is only meant for helper function when dealing with CLI-scripts

=cut

sub makeConfig {
    my %conf;
    $conf{SwitchOnRelayBCMPin} = $_[0] if $_[0];
    $conf{SwitchOffRelayBCMPin} = $_[1] if $_[1];
    $conf{ActivationTemperature} = $_[2] if $_[2];
    $conf{TargetTemperature} = $_[3] if $_[3];
    $conf{TemperatureCorrection} = $_[4] if $_[4];
    $conf{StatisticsWriteInterval} = $_[5] if $_[5];
    $conf{StatisticsLogFile} = $_[6] if $_[6];
    $conf{EmergencyShutdownTemperature} = $_[7] if $_[7];
    $conf{EmergencyPassedTemperature} = $_[8] if $_[8];
    $conf{TemperatureSensorsCount} = $_[9] if $_[9];
    $conf{MinimumHeatingEfficiency} = $_[10] if $_[10];
    $conf{Verbose}                  = $_[11] if $_[11];
    return \%conf;
}

=head2 setTimeZone
@STATIC @PARAMETERLESS

Autoconfigures the system timezone

=cut

sub setTimeZone {
    return $ENV{TZ} if $ENV{TZ};
    my $TZ = `/bin/cat /etc/timezone`;
    die "Timezone not defined in /etc/timezone" unless $TZ;
    chomp($TZ);
    my $tz = DateTime::TimeZone->new(name => $TZ);
    die "Timezone '$tz' from /etc/timezone is not valid" unless $tz;
    $ENV{TZ} = $TZ;
    return $ENV{TZ};
}

1;
