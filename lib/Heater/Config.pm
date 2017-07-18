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

use Config::Simple;
use DateTime::TimeZone;

my $configFile = "/etc/emb-heater/daemon.conf";

=head2 configure

Configures the whole program

@RETURNS Config::Simple

=cut

sub configure {
    my ($params) = @_;

    my $config = _mergeConfig($params);

    _setTimeZone();

    return $config;
}

=head2 mergeConfig

Take user parameters and system configuration and override with user parameters.
Validate config.

=cut

sub _mergeConfig {
    my ($params) = @_;

    my $config = _getConfig();
    while( my ($k,$v) = each(%$params) ) {
        $config->{$k} = $params->{$k};
    }
    _isConfigValid($config);
    return $config;
}

=head2

Get config and remove strange default-block

=cut

sub _getConfig {
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
sub _isConfigValid() {
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
        exitWithError("StatisticsWriteInterval is not a valid signed int");
    }
    if ($c->{StatisticsWriteInterval}) {
        unless(  $c->{StatisticsLogFile} && $c->{StatisticsLogFile} =~ /^.+$/  ) {
            exitWithError("StatisticsLogFile must be a valid path if StatisticsWriteInterval is defined");
        }
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
    return \%conf;
}

=head2 setTimeZone
@STATIC @PARAMETERLESS

Autoconfigures the system timezone

=cut

sub setTimeZone {
    return undef if $ENV{TZ};
    my $TZ = `/bin/cat /etc/timezone`;
    die "Timezone not defined in /etc/timezone" unless $TZ;
    chomp($TZ);
    my $tz = DateTime::TimeZone->new(name => $TZ);
    die "Timezone '$tz' from /etc/timezone is not valid" unless $tz;
    $ENV{TZ} = $TZ;
    return 1;
}

1;
