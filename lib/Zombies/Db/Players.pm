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
            bank::json->'amount' as money,
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
            $player_account->{units} //= [];
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

# TODO: probably move the actual messages to the spads plugin, and
# let the plugin decide how to render them (single message or multiple
# messages, etc.)
sub check_teams($self, $lobby_players, $cb) {
    my @names = keys $lobby_players->%*;
    my $delay = Mojo::IOLoop->delay(
        sub ($delay) {
            for my $player (@names) {
                # the 0 says "don't chop off the first argument from the
                # callback". we do this because the thing we're calling already
                # catches the 'die', so errors could go noticed if we chop like
                # that
                $self->find_or_create($player, $delay->begin(0));
            }
        },
        # weeee, delays are awesome!
        #
        # delays call the next sub with the delay, followed by
        # each of the arguments passed to each callback in series
        #
        # so with two players for find_or_create (which returns $err, $player)
        # the signature of this sub is ($delay, $err1, $player1, $err2, $player2 ... $errN, $playerN)
        #
        # the order is the same as the order the calls were made in (see the
        # loop in above sub)
        sub ($delay, @results) {
            my %players_without_units;
            my %teams;
            for my $player_name (@names) {
                my ($err, $player) = (shift @results, shift @results);

                die $err if $err;

                my $team_id = $lobby_players->{$player_name}->{battleStatus}->{team};
                $players_without_units{$player_name} = 1 if not $player->{units}->[0];
                $teams{$team_id}++;
            }

            my $team_count = scalar keys %teams;
            my $players_without_units_count = scalar keys %players_without_units;

            my $reason;
            if ($team_count != 3) {
                $reason = "there are $team_count ally teams - but really there should be 3";
            } elsif ($players_without_units_count > 1) {
                my $lacking_players = join ', ', keys %players_without_units;
                $reason = "$players_without_units_count players lack units: $lacking_players. go buy some stuff (!hq), you can't ALL be zombies!";
            }

            if ($reason) {
                $cb->(undef, { msg => $reason });
            } else {
                $cb->(undef, { ok => 1 });
            }
        }
    )->catch(sub ($, $err) {
        error("team validation: " . encode_json($lobby_players), $err, $cb);
    })->wait;
}

1;
