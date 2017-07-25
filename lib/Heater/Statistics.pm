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

use DateTime;
use DateTime::TimeZone;
use Scalar::Util qw(weaken);

use HeLog;
my $l = bless({}, 'HeLog');

sub new {
    my ($class, $heater) = @_;

    my $self = {heater => $heater};
    weaken($self->{heater});
    bless $self, $class;

    $self->{STATFILE} = $self->_getStatFileHandle();

    return $self;
}

sub h {
    return $_[0]->{heater};
}

=head2 _getStatFileHandle

Overload from tests to inject a in-memory variable to collect logs.

@RETURNS file handle to write statistics to

=cut

sub _getStatFileHandle {
    my ($self) = @_;

    $l->debug("Opening statistics file for writing: '".$self->h()->{StatisticsLogFile}."'");
    open(my $STATFILE, '>>:encoding(UTF-8)', $self->h()->{StatisticsLogFile}) or die $!;
    return $STATFILE;
}

my $tempReadingColWidth = 10;
sub writeStatistics {
    my ($self) = @_;
    my $STATFILE = $self->{STATFILE};

    my $date = DateTime->now(time_zone => $ENV{TZ})->iso8601();
    my $warming = $self->h()->isWarming() ? 1 : 0;
    my @temps = $self->h()->temperatures('type');

    my @tempPrintables;
    foreach my $temp (@temps) {
        warn "Temperature reading '$temp' exceeds printable column size '$tempReadingColWidth', increase it!" if (length $temp > $tempReadingColWidth);
        push(@tempPrintables, sprintf("\%${tempReadingColWidth}s", $temp));
    }

    print $STATFILE "$date - ".join(" & ",@tempPrintables)." - warming=$warming\n";

    return $self;
}

1;
