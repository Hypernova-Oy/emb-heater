# Copyright (C) 2017 Koha-Suomi
#
# This file is part of emb-heater.

package HeLog;

use Modern::Perl;
use Carp qw(longmess);
use Scalar::Util qw(blessed);
use Data::Dumper;

use Log::Log4perl;
our @ISA = qw(Log::Log4perl);
Log::Log4perl->wrapper_register(__PACKAGE__);

sub AUTOLOAD {
    my $l = shift;
    my $method = our $AUTOLOAD;
    $method =~ s/.*://;
    unless (blessed($l)) {
         longmess "HeLog invoked with an unblessed reference??";
    }
    unless ($l->{_log}) {
        $l->{_log} = get_logger($l);
    }
    return $l->{_log}->$method(@_);
}

sub get_logger {
    initLogger() unless Log::Log4perl->initialized();
    return Log::Log4perl->get_logger();
}

sub initLogger {
    my $config = Heater::Config::getConfig();
    my $l4pf = $config->{'Log4perlConfig'};

    #Incredible! The config file cannot be properly read unless it is somehow fiddled with from the operating system side.
    #Mainly fixes t/10-permissions.b.t
    #Where the written temp log4perl-config file cannot be read by Log::Log4perl
    #`/usr/bin/touch $l4pf` if -e $l4pf;

#print Data::Dumper::Dumper($config);
#use File::Slurp;
#warn File::Slurp::read_file($config->param('Log4perlConfig'));
#$DB::single=1;
#sleep 1;

    if ($ENV{HEATER_TEST_MODE}) {
        Log::Log4perl->init($l4pf); #init_and_watch causes Log::Log4perl to fail spectacularly trying to find log level is_INFO which doesn't exist.
    } else {
        Log::Log4perl->init_and_watch($l4pf, 10);
    }
    my $verbose = $ENV{HEATER_LOG_LEVEL} || $config->param('Verbose');
    Log::Log4perl->appender_thresholds_adjust($verbose);
}

=head2 flatten

    my $string = $logger->flatten(@_);

Given a bunch of $@%, the subroutine flattens those objects to a single human-readable string.

@PARAMS Anything, concatenates parameters to one flat string

=cut

sub flatten {
    my $self = shift;
    die __PACKAGE__."->flatten() invoked improperly. Invoke it with \$logger->flatten(\@params)" unless ((blessed($self) && $self->isa(__PACKAGE__)) || ($self eq __PACKAGE__));
    $Data::Dumper::Indent = 0;
    $Data::Dumper::Terse = 1;
    $Data::Dumper::Quotekeys = 0;
    $Data::Dumper::Maxdepth = 2;
    $Data::Dumper::Sortkeys = 1;
    return Data::Dumper::Dumper(\@_);
}

1;
