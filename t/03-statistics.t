#!/usr/bin/perl

use Modern::Perl;

use Test::More;
use Test::MockModule;

use File::Temp;
use Proc::PID::File;

use t::Examples;
use t::IPC;

use Heater;
use Heater::Config;


my $heaterDaemonName = 'heater';


subtest "TimeZone correctly set", \&timeZone;
sub timeZone {
  Heater::Config::setTimeZone();
  ok($ENV{TZ});
}


subtest "Monitor that a daemon generates statistics", \&monitorStatistics;
sub monitorStatistics {

  my ($conf, $tempFile, $statsRow, $todayYmd, @lines);

  #Firstly launch the heater daemon to monitor
  $conf = t::Examples::getStatisticalConf();
  $tempFile = File::Temp->new();
  $conf->{StatisticsLogFile} = $tempFile->filename;
  t::IPC::forkExec(t::Examples::getDaemonizingCommand( $conf ));
  sleep 1; #We need extra sleep because of the slow temperature reading.

  #We should start receiving statistical entries rapidly.
  subtest "Confirm statistical entry accuracy", sub {
    $todayYmd = DateTime->now(time_zone => $ENV{TZ})->ymd('-');
    $statsRow = $tempFile->getline();

    like($statsRow, qr/^${todayYmd}T\d{2}:\d{2}:\d{2} - /, "Temperature statistics has the correct YMD");
    like($statsRow, qr/ - (-?\d+\.?\d*)$/, "Temperature statistics has a sane temperature reading");
    ok(15 <= $1 && $1 <= 25, "Temperature reading is in office temperatures +15 - +25"); #If you run these tests in an extreme environment, you might have to tweak these boundaries :)
  };

  sleep 3; #Sleep a bit for the daemon to generate more statistics rows.
  $tempFile->seek(0,0); #rewind the pointer
  @lines = $tempFile->getlines(); #Get all lines in the temporary statistics file
  ok(scalar(@lines), "We got '".scalar(@lines)."' temperature readings already!");

  #Stop the daemon
  Heater::killHeater($conf);
  sleep 1; #Give some time to gracefully terminate
  ok(! Heater::getPid($conf)->alive(), "Heater is killed");

}

done_testing;
