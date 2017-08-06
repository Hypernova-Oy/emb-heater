package Heater::Exception;

use Modern::Perl;

use Scalar::Util qw(blessed weaken);
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

###  This is too scary to test! This might interfere with other modules in ways god only knows...
##Upgrade normal die-signals to Exception::Class
#$SIG{__DIE__} = sub {
#  Exception::Base->new(error => "@_");
#};

use Exception::Class (
#  'Exception::Base' => {
#    description => 'All die-signals are forced to this exception class',
#  },
  'Heater::Exception' => {
    description => 'Heater exceptions base class',
  },
);

=head2 rethrowDefault

TODO::Not working yet. How to generalize all those different ways of handling Exceptions in Perl?

Because there are so many different types of exception classes with different
interfaces, use this to rethrow since you dont know exactly what you are getting.

@PARAM1 somekind of monster

=cut

sub rethrowDefaults {
  my ($e) = @_;

  die $e unless blessed($e);
  die $e if $e->isa('Mojo::Exception'); #Dying a Mojo::Exception actually rethrows it.
  $e->rethrow if ref($e) eq 'Heater::Exception'; #If this is THE 'Hetula::Exception', then handle it here
  return $e if $e->isa('Heater::Exception'); #If this is a subclass of 'Hetula::Exception', then let it through
  $e->rethrow; #Exception classes are expected to implement rethrow like good exceptions should!!
}

=head2 toText

@RETURNS String, a textual representation of this exception,
                 Full::module::package :> error message, other supplied error keys

=cut

sub toText {
  my ($e) = @_;

  return _toTextFromRef($e) if (ref($e));
  return $e;
}

sub _toTextFromRef {
  my ($e) = @_;

  if (blessed($e)) {
    return _toTextFromExceptionClass($e) if ($e->isa('Heater::Exception'));
  }
  return _toTextFromHash($e);
  

}

sub _toTextFromHash {
  my ($e) = @_;
  my @sb;
  push(@sb, ref($e).' :> Unknown HASH Exception');

  my @k = sort keys %$e;
  foreach my $k (@k) {
    push(@sb, "$k => '".$e->{$k}."'");
  }
  return join(', ', @sb);
}

sub _toTextFromExceptionClass {
  my ($e) = @_;
  my @sb;
  push(@sb, ref($e).' :> '.$e->error);

  my @k = sort keys %$e;
  foreach my $k (@k) {
    next if $k eq 'error';
    push(@sb, "$k => '".$e->{$k}."'");
  }
  return join(', ', @sb);
}

1;
