package Zombies::Db::Games;
use 5.20.1;

use Mojo::Base -base;
use Mojo::JSON qw(encode_json);
use Mojo::IOLoop;

use Zombies::Db;
use Zombies::Db::UnitDefs;

use experimental qw(postderef signatures);

has pg => sub { Zombies::Db::handle() };

sub start ($self, $game_id, $players, $cb) {
    my @players = $players->@*;
    # hack hack hack.
    my $bind_targets = substr '?, ' x @players, 0, -2;
    # check out units
    my $sql = "UPDATE unit SET ingame = ? WHERE owner IN ($bind_targets)";
    my @params = ($game_id, @players);
    $self->pg->db->query($sql, @params, sub ($, $err, $results) {
        $cb->(undef, !!$results->rows);
    });
}

1;
