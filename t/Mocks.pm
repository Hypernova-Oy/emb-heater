package t::Mocks;

use Modern::Perl;

use Test::More;

sub mockStatisticsFileWritingToScalar {
    my ($moduleStatisticsOverload, $statisticsInMemLogPtr) = @_;
    $moduleStatisticsOverload->mock('_getStatFileHandle', sub {
        my ($FH, $ptr) = t::Mocks::reopenScalarHandle(undef, $statisticsInMemLogPtr);
        return $FH;
    });
}

=head2 reopenScalarHandle

This works like magic :)

@PARAM1 File handle or undef, File handle to reopen to point to the flushed scalar
@PARAM2 Pointer to scalar, Points to a variable which receives the output.
@RETURNS List of File handle       - Write in this to append contents to the pointed scalar
                 Pointer to scalar - Points to the variable storing the written output.

=cut

sub reopenScalarHandle {
    my ($LOGFILEOUT, $pointerToScalar) = @_;
    $$pointerToScalar = '';
    close($LOGFILEOUT) if $LOGFILEOUT;
    open($LOGFILEOUT, '>:encoding(UTF-8)', $pointerToScalar) or die $!;
    $LOGFILEOUT->autoflush ( 1 );
    select $LOGFILEOUT; #Use this as the default print target, so Console appender is redirected to this logfile
    return ($LOGFILEOUT, $pointerToScalar);
}

=head2 testState

Tests that Heather is in proper internal state

=cut

sub testState {
  my ($heater, $state, $isWarming) = @_;

  my $ok = 1;
  $ok = is($heater->state->name, $state, "Heather is in the expected state '$state'") if $state;
  $ok = is($heater->isWarming(), $isWarming, "Heather ".($isWarming ? 'is' : 'isnt')." warming") if(defined($isWarming));
  return $ok;
}

=head2 makeTempsMockerSub

@PARAMS List of temperatures the specific temperature sensors should return
@RETURNS Anonymous subroutine (closure) which replaces the mocked subroutine.

=cut

sub makeTempsMockerSub {
    my @temps = @_;
    my $sensors = $main::TEST_SENSORS;
    return sub {
        return $temps[0] if ($_[0]->id eq $sensors->[0]->id);
        return $temps[1] if ($_[0]->id eq $sensors->[1]->id);
        #return $temps[2] if ($_[0]->id eq $sensor3ID);
    };
}

1;
