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
    my @stuff = $self->pg->db->query('INSERT INTO player (name) VALUES (?)', $name);
    return @stuff;
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
                $cb->($results->expand->hash);
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
                $self->pg->db->query($sql, encode_json($bank), $player_name, $delay->begin);
            }
        },
        sub ($, $, $results) {
            $cb->(!!$results->rows);
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
    my $sql = "UPDATE unit SET ingame = ? WHERE owner IN ($bind_targets)";
    my @params = ($game_id, @players);
    $self->pg->db->query($sql, @params, sub ($, $err, $results) {
        $cb->(!!$results->rows);
    });
}

sub buy_unit($self, $player_name, $unitdef, $cb) {
    # TODO
    Mojo::IOLoop->delay(
        sub ($delay) {

        },

        sub ($delay, $, $results) {

        }
    )->catch(sub { 

    })->wait;
    #my $sql = 'INSERT INTO unit (owner, stats) VALUES (?, ?)';
    #my $results = $self->pg->db->query($sql, $player_name, encode_json $unit);
    #$cb->($results);
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
