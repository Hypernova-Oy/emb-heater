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

package Heater::Statistics;

our $VERSION = "0.01";

use Modern::Perl;
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

use Sys::Syslog qw(:standard :macros);
use Time::HiRes;
use DateTime;
use DateTime::TimeZone;
use Scalar::Util qw(weaken);

sub new {
    my ($class, $heater) = @_;

    my $self = {heater => weaken($heater)};
    bless $self, $class;

    open(my $STATFILE, '>>:encoding(UTF-8)', $self->h()->{StatisticsLogFile}) or die $!;
    $self->{STATFILE} = $STATFILE;

    return $self;
}

sub h {
    return $_[0]->{heater};
}

my $tempReadingColWidth = 10;
sub writeStatistics {
    my ($self) = @_;
    my $STATFILE = $self->{STATFILE};

    my $date = DateTime->now(time_zone => $ENV{TZ})->iso8601();
    my $warming = $self->h()->isWarming() ? 1 : 0;
    my @temps = $self->h()->temperatures('type');

    print $STATFILE "$date - ".join(" & ",@temps)." - warming=$warming\n";

    return $self;
}

1;
