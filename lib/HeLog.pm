# Copyright (C) 2017 Koha-Suomi
#
# This file is part of emb-heater.

package HeLog;

use Modern::Perl;
use Carp qw(longmess);
use Scalar::Util qw(blessed);
use Data::Dumper;

#use Log::Log4perl qw(:easy);
use Log::Log4perl;
our @ISA = qw(Log::Log4perl);
Log::Log4perl->wrapper_register(__PACKAGE__);

my $environmentAdjustmentDone; #Adjust all appenders only once

sub AUTOLOAD {
    my $l = shift;
    my $method = our $AUTOLOAD;
    $method =~ s/.*://;
    return if $method eq 'DESTROY';

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
    my $l = Log::Log4perl->get_logger();
    $l->level(_levelToLog4perlLevelInt($ENV{HEATER_LOG_LEVEL})) if $ENV{HEATER_LOG_LEVEL};
    return $l;
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
        Log::Log4perl->easy_init({level => _levelToLog4perlLevelInt($ENV{HEATER_LOG_LEVEL} || 'TRACE'),
                                  utf8 => 1,
                                 });
    } else {
        Log::Log4perl->init_and_watch($l4pf, 10);
    }
}

=head2 _levelToLog4perlLevelInt

There is a bug in Log4perl, where loading
    use Log::Log4perl qw(:easy);
to namespace in this file causes
    Deep recursion on subroutine "Log::Log4perl::get_logger" at /usr/share/perl5/Log/Log4perl.pm line 339, <FH> line 92.

Work around by not importing log levels, and manually duplicating them here.
see /usr/share/perl5/Log/Log4perl/Level.pm for level integers

=cut

sub _levelToLog4perlLevelInt {
    return 0             if $_[0] =~ /ALL/i;
    return 5000          if $_[0] =~ /TRACE/i;
    return 10000         if $_[0] =~ /DEBUG/i;
    return 20000         if $_[0] =~ /INFO/i;
    return 30000         if $_[0] =~ /WARN/i;
    return 40000         if $_[0] =~ /ERROR/i;
    return 50000         if $_[0] =~ /FATAL/i;
    return (2 ** 31) - 1 if $_[0] =~ /OFF/i;  #presumably INT MAX
    die "_levelToLog4perlLevelInt($_[0]):> Unknown log level $_[0].".($ENV{HEATER_LOG_LEVEL} ? " Log level set in \$ENV{HEATER_LOG_LEVEL} => '$ENV{HEATER_LOG_LEVEL}'" : "");
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
