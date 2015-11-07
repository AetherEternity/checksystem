package CS::Model::Scoreboard;
use Mojo::Base 'MojoX::Model';

use Convert::Color;
use List::Util qw/first max/;

sub generate {
  my $self = shift;
  my $db   = $self->app->pg->db;

  # Calculate score for each service
  my $services;
  my $scoreboard = $db->query('select * from scoreboard')->expand->hashes;
  $scoreboard->map(sub { push @{$services->{$_->{id}}{all}}, $_->{sla} * $_->{fp} for @{$_->{services}} });
  $services->{$_}{max} = max @{$services->{$_}{all}} for keys %$services;
  $scoreboard->map(
    sub {
      for my $s (@{$_->{services}}) {
        if (($s->{status} // 0) != 101) {
          my $state = first { defined $s->{result}{$_}{exit_code} } (qw/get_2 get_1 put check/);
          $s->{title} = $s->{result}{$state}{stdout} // '' if $state;
        }
        my $c = $self->app->model('checker')->status2color($s->{status});
        if ($c->as_rgb8->hex eq 'ffffff') { $s->{bgcolor} = '#ffffff'; next }

        my $rate = $services->{$s->{id}}{max} == 0 ? 1 : ($s->{sla} * $s->{fp} / $services->{$s->{id}}{max});
        $c = $c->as_hsv;
        my $nc = Convert::Color::HSV->new($c->hue, 0.5 + $c->saturation * 0.5 * $rate, $c->value);
        $s->{bgcolor} = '#' . $nc->as_rgb8->hex;
      }
    }
  );

  return ({scoreboard => $scoreboard, round => $db->query('select max(n) from rounds')->array->[0]});
}

1;
