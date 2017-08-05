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

package t::IPC;

#Pragmas
use Modern::Perl;

#Public modules
use Storable;

use HeLog;
my $l = bless({}, 'HeLog');

sub forkExec {
    my ($cmd) = @_;
    my $pid = fork();
    if ($pid == 0) { #I am a child
        $l->info("Forking Heater-process with command: $cmd");
        exec $cmd;
        exit 0;
    }
    else {
        sleep 1; #Sleep a bit to give time for the forked process to execute
    }
    return $pid; #Return the forked pid to the caller.
}

1;
