package Zombies::Db::Players;
use 5.20.1;

use Mojo::Base -base;
use Mojo::JSON qw(encode_json);
use Mojo::IOLoop;

use Zombies::Db;
use Zombies::Util qw(error);
use Zombies::Constants qw(STARTING_MONEY);

use experimental qw(postderef signatures);

has pg => sub { Zombies::Db::handle() };

sub find_or_create($self, $name, $cb) {
    $self->find($name => sub ($err, $player = undef) {
        if ($player) {
            $cb->(undef, $player);
        } else {
            $player = $self->create($name);
            if ($player) {
                $self->find($name, $cb);
            } else {
                # player didn't exist for the 'find' but appeared before the 'create'.
                # just run this again and it'll work.
                $cb->("try_again");
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
        sub ($, $, $results) {
            die { msg => "no such player", sev => 0 } if !$results->rows;

            my $player_account = $results->expand->hash;
            $cb->(undef, $player_account);
        }
    )->catch(sub ($, $err) {
        error("trying to find player: $player_name", $err, $cb);
    })->wait;
}

sub bank_transaction($self, $player_name, $transaction, $cb) {
    my $sql = 'SELECT bank FROM player WHERE name = ?';
    Mojo::IOLoop->delay(
        sub ($delay) {
            $self->pg->db->query($sql, $player_name, $delay->begin);
        },
        sub ($delay, $, $results) {
            die { msg => "no_such_player", sev => 0 } if !$results->rows;
            my $bank = $results->expand->hash->{bank} // {};
            my $sql = 'UPDATE player SET bank = ? WHERE name = ?';
            $bank->{amount} += $transaction->{amount};
            $delay->data(cash => $bank->{amount});
            $self->pg->db->query($sql, encode_json($bank), $player_name, $delay->begin);
        },
        sub ($delay, $, $results) {
            die { msg => "no rows updated after bank transaction", sev => 1 } if !$results->rows;
            $cb->(undef, $delay->data('cash'));
        },
    )->catch(sub ($, $err) {
        error("bank transaction: $player_name and " . encode_json($transaction), $err, $cb);
    })->wait;
}

1;
