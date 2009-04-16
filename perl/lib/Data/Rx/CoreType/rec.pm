use strict;
use warnings;
package Data::Rx::CoreType::rec;
use base 'Data::Rx::CoreType';
# ABSTRACT: the Rx //rec type

use Scalar::Util ();

sub subname   { 'rec' }

sub new_checker {
  my ($class, $arg, $rx) = @_;
  my $self = $class->SUPER::new_checker({}, $rx);

  Carp::croak("unknown arguments to new") unless
  Data::Rx::Util->_x_subset_keys_y($arg, {
    rest     => 1,
    required => 1,
    optional => 1,
  });

  my $content_schema = {};

  $self->{rest_schema} = $rx->make_schema($arg->{rest}) if $arg->{rest};

  TYPE: for my $type (qw(required optional)) {
    next TYPE unless my $entries = $arg->{$type};

    for my $entry (keys %$entries) {
      Carp::croak("$entry appears in both required and optional")
        if $content_schema->{ $entry };

      $content_schema->{ $entry } = {
        optional => $type eq 'optional',
        schema   => $rx->make_schema($entries->{ $entry }),
      };
    }
  };

  $self->{content_schema} = $content_schema;
  return $self;
}

sub validate {
  my ($self, $value) = @_;

  unless (! Scalar::Util::blessed($value) and ref $value eq 'HASH') {
    $self->fail({
      error   => [ qw(type) ],
      message => "value was not a hashref",
    });
  }

  my $c_schema = $self->{content_schema};

  my @rest_keys = grep { ! exists $c_schema->{$_} } keys %$value;
  if (@rest_keys and not $self->{rest_schema}) {
    $self->fail({
      error   => [ qw(unknown) ],
      entry   => \@rest_keys,
      message => "found unexpected entries: @rest_keys",
    });
  }

  for my $key (keys %$c_schema) {
    my $check = $c_schema->{$key};

    if (not $check->{optional} and not exists $value->{$key}) {
      $self->fail({
        error   => [ qw(missing) ],
        entry   => $key,
        message => "no value given for required entry $key",
      });
    }

    if (exists $value->{$key}) {
      $self->_subcheck(
        { entry => $key },
        sub { $check->{schema}->validate($value->{$key}) }
      );
    }
  }

  if (@rest_keys) {
    my %rest = map { $_ => $value->{$_} } @rest_keys;

    $self->_subcheck(
      { entry => undef },
      sub { $self->{rest_schema}->validate(\%rest) },
    );
  }

  return 1;
}

1;
