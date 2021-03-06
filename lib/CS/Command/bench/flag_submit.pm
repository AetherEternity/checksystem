package CS::Command::bench::flag_submit;
use Mojo::Base 'Mojolicious::Command';

has description => 'Send flags';

use Mojo::IOLoop;

sub run {
  my $app = shift->app;
  my $db  = $app->pg->db;

  my $flags = $db->query('select * from flags order by random() limit 1000')->hashes;
  my $teams = $flags->reduce(sub { $a->{$b->{team_id}} = $app->teams->{$b->{team_id}}{host}; $a }, {});

  for my $team_id (keys %$teams) {
    my $id;
    $id = Mojo::IOLoop->client(
      address       => '127.0.0.1',
      port          => 31337,
      local_address => $teams->{$team_id},
      timeout       => 10,
      sub {
        my ($loop, $err, $stream) = @_;

        if ($err) {
          warn "Error while connect $teams->{$team_id}: $err";
          return;
        }

        my $c = sub {
          my $payload = $flags->shuffle->first->{data};
          $stream->write("$payload\n");
        };

        $stream->on(error => sub { warn "[$id] stream error: $_[1]" });
        $stream->on(close => sub { warn "[$id] close stream" });
        $stream->on(read  => sub { $c->(); });

        $c->();
      }
    );
  }

  Mojo::IOLoop->start;
}

1;
