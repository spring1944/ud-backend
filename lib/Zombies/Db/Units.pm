package Zombies::Db::Units;
use 5.20.1;

use Mojo::Base -base;
use Mojo::JSON qw(encode_json);
use Mojo::IOLoop;

use Zombies::Db;
use Zombies::Db::UnitDefs;
use Zombies::Db::Players;
use Zombies::Util qw(error);
use Zombies::Constants qw(SELL_PENALTY);

use experimental qw(postderef signatures);
use Data::Dumper qw(Dumper);

has pg => sub { Zombies::Db::handle() };

my $players = Zombies::Db::Players->new;

sub add($self, $player_name, $unit, $cb) {
    $self->pg->db->query('INSERT INTO unit (owner, stats) VALUES (?, ?)', $player_name, encode_json($unit), $cb);
}

sub buy($self, $player_name, $unit_name, $cb) {
    my $delay = Mojo::IOLoop->delay(
        sub ($delay) {
            $self->pg->db->query('SELECT bank from player where name = ?', $player_name, $delay->begin);
        },
        sub ($delay, $, $results) {
            my $bank = $results->expand->hash->{bank};
            die { msg => "no_such_player", sev => 0 } if !$bank;

            $delay->data(cash => $bank->{amount});
            my $sql = 'SELECT name, cost, health, ammo FROM unitdef WHERE name = ?';
            $self->pg->db->query($sql, $unit_name, $delay->begin);
        },
        sub ($delay, $, $result) {
            my $unitdef = $result->expand->hash;
            die { msg => "no such unitdef: $unit_name", sev => 0 } if !$unitdef;

            my $cost = $unitdef->{cost};
            my $unit_stats = { $unitdef->%{qw(health ammo name)}, experience => 0 };
            my $cash = $delay->data('cash');

            die { msg => "unit has no cost: $unit_name", sev => 1 } if !$cost;
            die { msg => "not enough command", sev => 0 } if $cost > $cash;

            $players->bank_transaction($player_name, { amount => -1 * $cost }, $delay->begin);
            $delay->data(cash => $cash - $cost);
            $delay->data(unit => $unit_stats);
            $self->add($player_name, $unit_stats, $delay->begin);
        },
        sub ($delay, $remaining_balance, $, $add_unit_results) {
            my $success = !!$remaining_balance && !!$add_unit_results->rows;

            die { msg => "failure to apply bank transaction", sev => 1 } if !$success;

            $cb->(undef, $delay->data('cash'), $delay->data('unit'));
        }
    )->catch(sub ($, $err) {
        error("buying unit $player_name: $unit_name", $err, $cb);
    })->wait;
}


sub sell($self, $player_name, $unit_id, $cb) {
    my $delay = Mojo::IOLoop->delay(
        sub ($delay) {
            my $sql = "
                SELECT
                    owner,
                    stats as unit,
                    health as max_health,
                    cost
                FROM
                    unit
                JOIN
                    unitdef
                ON
                    unit.stats::json->>'name' = unitdef.name
                WHERE id = ? AND owner = ?";
            $self->pg->db->query($sql, $unit_id, $player_name, $delay->begin);
        },
        sub ($delay, $, $result) {
            my $data = $result->expand->hash;
            my $unit = $data->{unit};

            die { msg => "no_such_unit", sev => 0 } if !$unit;

            my $def = { $data->%{qw(max_health cost)} };
            my $percent_health_left = $unit->{health} / $def->{max_health};
            my $worth = $percent_health_left * $def->{cost} * (1 - SELL_PENALTY);
            # begin(0) means 'include the first arg given to the callback'
            $players->bank_transaction($data->{owner}, { amount => $worth }, $delay->begin(0));
            $self->pg->db->query('DELETE FROM unit where id = ?', $unit_id);
        },
        sub ($delay, $, $balance) {
            $cb->(undef, $balance);
        }
    )->catch(sub ($, $err) {
        error("selling unit $unit_id", $err, $cb);
    })->wait;
}

sub check_in($self, $player_name, $unit, $cb) {
    my $sql = 'UPDATE unit SET stats = ?, ingame = NULL WHERE id = ? AND owner = ?';
    my $to_store = { $unit->%{qw(ammo name health experience)} };
    my @params = (encode_json($to_store), $unit->{hq_id}, $player_name);
    my $delay = Mojo::IOLoop->delay(
        sub ($delay) {
            $self->pg->db->query($sql, @params => $delay->begin);
        },
        sub ($delay, $, $results) {
            die { msg => "no unit updated", sev => 1} if !$results->rows;
            $cb->(undef, 1);
        }
    )->catch(sub ($, $err) {
        error("problem while checking in unit $unit->{id}: $err", $err, $cb);
    })->wait;
}

sub repair($self, $player_name, $unit, $cb) {

}

1;
