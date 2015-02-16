package Zombies::Db::Players;
use 5.20.1;

use Mojo::Base -base;
use Mojo::JSON qw(encode_json);
use Mojo::IOLoop;

use Crypt::GeneratePassword qw(chars);

use Zombies::Db;
use Zombies::Util qw(error);
use Zombies::Constants qw(STARTING_MONEY MIN_ARMY_SIZE);

use experimental qw(postderef signatures);

has pg => sub { Zombies::Db::handle() };

sub find_or_create($self, $name, $cb) {
    my $delay = Mojo::IOLoop->delay(
        sub ($delay) {
            $self->find($name => $delay->begin(0));
        },
        sub ($delay, $err, $player = undef) {
            if ($player) {
                $cb->(undef, $player);
            } else {
                $player = $self->create($name);
                if ($player) {
                    $self->find($name, $cb);
                } else {
                    # player didn't exist for the 'find' but appeared before the 'create'.
                    # just run this again and it'll work.
                    die "try again";
                }
            }
        }
    )->catch(sub ($, $err) {
        error("find or create: $name", $err, $cb);
    })->wait;
}

sub generate_access_token($self, $name) {
    my $key = chars(7, 12, ['a' .. 'Z']);
    my $sql = 'UPDATE player set hq_access_token = ?, hq_access_token_created = NOW() where name = ?';
    my $result = $self->pg->db->query($sql, $key, $name);
    return $key if $result;
}

sub get_access_token($self, $player_name) {
    say "fetching access token for $player_name";
    my $sql = "SELECT hq_access_token from player where name = ? AND hq_access_token_created > (current_timestamp - interval '1 hour')";
    my $result = $self->pg->db->query($sql, $player_name);
    return '' if !$result->rows;
    my $creds = shift $result->hashes->to_array->@*;
    return $creds->{hq_access_token} if $creds;
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
            side,
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

sub set_side($self, $player_name, $side, $cb) {
    my $sql = "UPDATE player set side = ? where name = ?";

    Mojo::IOLoop->delay(
        sub ($delay) {
            $self->pg->db->query($sql, $side, $player_name, $delay->begin);
        },
        sub ($, $, $results) {
            die { msg => "no such player", sev => 0 } if !$results->rows;
            $cb->(undef, $side);
        }
    )->catch(sub ($, $err) {
        error("setting player side: $player_name to $side", $err, $cb);
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
                $players_without_units{$player_name} = 1 if scalar $player->{units}->@* < MIN_ARMY_SIZE;
                $teams{$team_id}++;
            }

            my $team_count = scalar keys %teams;
            my $players_without_units_count = scalar keys %players_without_units;

            my $reason;
            if ($team_count != 3) {
                $reason = "there are $team_count ally teams - but really there should be 3";
            } elsif ($players_without_units_count > 1) {
                my $lacking_players = join ', ', keys %players_without_units;
                $reason = "$players_without_units_count players have none or very few units: $lacking_players. go buy some stuff (!hq), you can't ALL be zombies!";
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
