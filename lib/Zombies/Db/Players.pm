package Zombies::Players;
use Mojo::Base -base;
use Zombies::Db;
use Zombies::Logger;
use Zombies::Db::UnitDefs;
use Mojo::JSON qw(encode_json);
use Mojo::IOLoop;
use 5.20.1;
use experimental qw(postderef signatures);
use Data::Dumper qw(Dumper);

has logger => sub { Zombies::Logger::logger() };
has pg => sub { Zombies::Db::handle() };

use constant STARTING_MONEY => 100_000;
use constant SELL_PENALTY => 0.05;

sub find_or_create($self, $name, $cb) {
    $self->find($name => sub ($player, $err = undef) {
        if ($player) {
            $cb->($player);
        } else {
            $player = $self->create($name);
            if ($player) {
                $self->find($name, $cb);
            } else {
                # player didn't exist for the 'find' but appeared before the 'create'.
                # just run this again and it'll work.
                $cb->(undef, "try_again");
            }
        }
    });
}

sub create ($self, $name) {
    my $result = $self->pg->db->query("INSERT INTO player (name, bank) VALUES (?, ?)", $name, encode_json({ amount => STARTING_MONEY}));
    return !!$result;
}

sub find ($self, $player_name, $cb) {
    # unique key on name
    my $sql = "
        SELECT
            id,
            name,
            bank,
            (SELECT array_to_json(array_agg( row_to_json(t)))
                FROM ( SELECT id, stats from unit WHERE owner = ?) t) AS units
        FROM
            player
        WHERE
            name = ?";
    my @params = ($player_name, $player_name);

    Mojo::IOLoop->delay(
        sub ($delay) {
            $self->pg->db->query($sql, @params, $delay->begin);
        },
        sub ($, $, $results ) {
            if ($results->rows) {
                my $foo = $results->expand->hash;
                $cb->($foo);
            } else {
                $cb->(undef);
            }
        }
    )->catch(sub ($, $err) {
        $self->logger->error("problem while finding $player_name: $err");
        $cb->(undef, "an error occurred");
    })->wait;
}

sub bank_transaction($self, $player_name, $transaction, $cb) {
    my $sql = 'SELECT bank FROM player WHERE name = ?';
    Mojo::IOLoop->delay(
        sub ($delay) {
            $self->pg->db->query($sql, $player_name, $delay->begin);
        },
        sub ($delay, $, $results) {
            if (!$results->rows) {
                $cb->(undef);
            } else {
                my $bank = $results->expand->hash->{bank} // {};
                my $sql = 'UPDATE player SET bank = ? WHERE name = ?';
                $bank->{amount} += $transaction->{amount};
                $delay->data(cash => $bank->{amount});
                $self->pg->db->query($sql, encode_json($bank), $player_name, $delay->begin);
            }
        },
        sub ($delay, $, $results) {
            if (!!$results->rows) {
                $cb->($delay->data('cash'));
            } else {
                $cb->(undef);
            }
        },
    )->catch(sub ($, $err) {
        $self->logger->error("problem while applying bank transaction (" . encode_json($transaction) . ") for $player_name: $err");
        $cb->(undef, $err);
    })->wait;
}

sub start_game ($self, $game_id, $players, $cb) {
    my @players = $players->@*;
    # hack hack hack.
    my $bind_targets = substr '?, ' x @players, 0, -2;
    # check out units
    my $sql = "UPDATE unit SET ingame = ? WHERE owner IN ($bind_targets)";
    my @params = ($game_id, @players);
    $self->pg->db->query($sql, @params, sub ($, $err, $results) {
        $cb->(!!$results->rows);
    });
}

sub add_unit($self, $player_name, $unit, $cb) {
    $self->pg->db->query('INSERT INTO unit (owner, stats) VALUES (?, ?)', $player_name, encode_json($unit), $cb);
}

sub buy_unit($self, $player_name, $unit_name, $cb) {
    my $delay = Mojo::IOLoop->delay(
        sub ($delay) {
            $self->pg->db->query('SELECT bank from player where name = ?', $player_name, $delay->begin);
        },
        sub ($delay, $, $results) {
            my $bank = $results->expand->hash->{bank};
            if ($bank) {
                $delay->data(cash => $bank->{amount});
                my $sql = 'SELECT name, cost, health, ammo FROM unitdef WHERE name = ?';
                $self->pg->db->query($sql, $unit_name, $delay->begin);
            } else {
                $cb->(undef, undef);
            }
        },
        sub ($delay, $, $result) {
            my $unit = $result->expand->hash;
            my $cost = $unit->{cost};
            my $unit_stats = { $unit->%{qw(health ammo name)}, experience => 0 };
            my $cash = $delay->data('cash');
            if ($cost and $cash > $cost) {
                $self->bank_transaction($player_name, { amount => -1 * $cost }, $delay->begin);
                $delay->data(cash => $cash - $cost);
                $self->add_unit($player_name, $unit_stats, $delay->begin);
            } else {
                $cb->(undef, undef);
            }
        },
        sub ($delay, $, $results) {
            $cb->(1, $delay->data('cash'));
        }
    )->catch(sub ($, $err) {
        $self->logger->error("problem while buying unit: $player_name, $unit_name $err");
        $cb->(undef, $err);
    })->wait;
}

sub sell_unit($self, $player_name, $unit_id, $cb) {
    my $delay = Mojo::IOLoop->delay(
        sub ($delay) {
            my $sql = "
                SELECT
                    stats as unit,
                    health as max_health,
                    cost
                FROM
                    unit
                JOIN
                    unitdef
                ON
                    unit.stats::json->>'name' = unitdef.name
                WHERE id = ? and owner = ?";
            $self->pg->db->query($sql, $unit_id, $player_name, $delay->begin);
        },
        sub ($delay, $, $result) {
            my $data = $result->expand->hash;
            my $unit = $data->{unit};
            if ($unit) {
                my $def = {$data->%{qw(max_health cost)}};
                my $percent_health_left = $unit->{health} / $def->{max_health};
                my $worth = $percent_health_left * $def->{cost} * (1 - SELL_PENALTY);
                # begin(0) means 'include the first arg given to the callback'
                $self->bank_transaction($player_name, { amount => $worth }, $delay->begin(0));
                $self->pg->db->query('DELETE FROM unit where id = ? and owner = ?', $unit_id, $player_name);
            } else {
                $cb->(undef, undef);
            }
        },
        sub ($delay, $balance) {
            $cb->(1, $balance);
        }
    )->catch(sub ($, $err) {
        $self->logger->error("problem while selling unit $unit_id ($player_name): $err");
        $cb->(undef, undef, $err);
    })->wait;
}

sub repair_unit($self, $player_name, $unit, $cb) {

}

sub check_in_unit($self, $player_name, $unit, $cb) {
    my $sql = 'UPDATE unit SET stats = ?, ingame = NULL WHERE id = ? AND owner = ?';
    my $to_store = { $unit->%{qw(ammo name health experience)} };
    my @params = (encode_json($to_store), $unit->{id}, $player_name);
    my $results = $self->pg->db->query($sql, @params => sub ($db, $err, $results) {
        $cb->(!!$results);
    });
}

1;
