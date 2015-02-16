#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::JSON qw(encode_json);
use 5.20.1;
use lib 'lib';
use experimental qw(signatures postderef);
use Zombies::Db::Players;
use Zombies::Db::Units;
use Zombies::Db::Games;
use Zombies::Db::UnitDefs;

my $players = Zombies::Db::Players->new;
my $units = Zombies::Db::Units->new;
my $games = Zombies::Db::Games->new;
my $unitdefs = Zombies::Db::UnitDefs->new;

get '/hq/unitdefs/:side' => sub ($c) {
    my $side = $c->param('side');
    $unitdefs->get_side_units($side => sub ($err, $units = undef) {
        if (defined $err) {
            $c->render(json => {error => "$err"});
        } else {
            $c->render(json => {units => $units});
        }
    });
};

get '/login/:player_name/:access_token' => sub ($c) {
    my $user = $c->param('player_name');
    my $given_token = $c->param('access_token');
    my $stored_token = $players->get_access_token($user);
    if ($given_token eq $stored_token) {
        $c->session({player_name => $user, access_token => $stored_token});
        # expire the cookie after an hour
        $c->session(expiration => 3600);
        $c->redirect_to('/hq');
    } else {
        $c->render(text => "bad access token for $user. it might have expired: ask the Zombies bot for a new access link with !hq", status => 401);
    }
};

under sub ($c) {
    my $user = $c->session('player_name');
    my $given_token = $c->session('access_token');

    if ($user) {
        my $stored_token = $players->get_access_token($user);
        $c->stash(player => $user);
        return 1 if $stored_token eq $given_token;

        $c->render(text => "bad access token for $user. it might have expired: ask the Zombies bot for a new access link with !hq", status => 401);
        return undef;
    } else {
        $c->render(text => "no user information in the cookie. make sure you click the link from the Zombie bot in lobby after asking with !hq", status => 402);
        return undef;
    }
};

post '/set_side' => sub ($c) {
    my $player_name = $c->stash('player');
    my $side = $c->param('side');
    $players->set_side($player_name, $side, sub ($err, $success = undef) {
        if (defined $err) {
            $c->render(text => "blorg error! $err");
        } else {
            $c->redirect_to('/hq');
        }
    });
};

get '/hq' => sub ($c) {
    my $player_name = $c->stash('player');
    my $delay = Mojo::IOLoop->delay(
        sub ($delay) {
            $players->find_or_create($player_name => $delay->begin);
        },
        sub ($delay, $player) {
            $delay->data(player => $player);
            if (not defined $player->{side}) {
                $c->render(
                    template => 'pick-a-side',
                    player => $player
                );
            } else {
                $unitdefs->get_side_units($player->{side} => $delay->begin(0));
            }
        },
        sub ($delay, $err, $units) {
            $c->render(
                template => 'index',
                unitdefs => $units,
                player => $delay->data('player')
            );
        }
    )->catch(sub ($, $err) {
        $c->render(text => "blarg error: $err", status => 500);
    })->wait;
};

# buy unit
post '/units/:unitdef' => sub ($c) {
    my $player_name = $c->stash('player');
    my $unitdef = $c->param('unitdef');
    $units->buy($player_name, $unitdef, sub ($err, $remaining_money = undef, $units = []) {
        if (defined $err) {
            $c->render(json => {error => "$err"});
        } else {
            $c->render(json => {balance => $remaining_money, units => $units});
        }
    });
};

# sell unit
del '/units/:unit_id' => sub ($c) {
    my $player_name = $c->stash('player');
    my $unit_id = $c->param('unit_id');
    $units->sell($player_name, $unit_id, sub ($err, $new_account_balance = undef) {
        if (defined $err) {
            $c->render(json => {error => "$err"});
        } else {
            $c->render(json => {balance => $new_account_balance});
        }
    });
};

# here down is for the SPADS plugin only
# TODO: add some config and don't have creds in code
under sub ($c) {
    my $auth = $c->req->url->to_abs->userinfo || '';
    my ($user, $given_token) = split ':', $auth, 2;

    return 1 if $user eq 'dog' and $given_token eq 'cat';
    $c->render(text => "NO GOOD");
    return undef;
};

get '/:player_name/token' => sub ($c) {
    my $player_name = $c->param('player_name');
    $players->find_or_create($player_name => sub ($err, $player = undef) {
        if ($err) {
            $c->render(text => "blarg error: $err. talk to admin", status => 500);
        } else {
            my $token = $players->generate_access_token($player_name);
            my $creds = { name => $player_name, token => $token };
            $c->render(json => $creds);
        }
    });
};

get '/:player_name' => sub ($c) {
    my $player_name = $c->param('player_name');
    $players->find_or_create($player_name => sub ($err, $player = undef) {
        if ($err) {
            $c->render(text => "blarg error. talk to admin", status => 500);
        } else {
            $c->render(json => $player);
        }
    });
};

post '/:player_name/bank' => sub ($c) {
    my $player_name = $c->param('player_name');
    my $transaction = $c->req->json;
    $players->bank_transaction($player_name, $transaction, sub ($err, $new_amount = undef) {
        if ($err) {
            $c->render(text => "blarg error. talk to admin", status => 500);
        } else {
            if (defined $new_amount) {
                $c->render(json => {success => 1});
            } else {
                $c->render(json => {error => "no such player"});
            }
        }
    });
};

post '/valid_teams' => sub ($c) {
    my $lobby_players = $c->req->json;
    if (scalar keys $lobby_players->%* == 0) {
        $c->render(json => { reason_for_not_starting => "no players!" });
    } else {
        $players->check_teams($lobby_players, sub ($err, $result = undef) {
            if ($err) {
                $c->render(json => { msg => "blarg error: $err. talk to admin" } , status => 500);
            } else {
                if ($result->{ok}) {
                    $c->render(json => { ok => 1 });
                } else {
                    $c->render(json => { reason_for_not_starting => $result->{msg} });
                }
            }
        });
    }
};

post '/games/:game_id/start' => sub ($c) {
    my $game_id = $c->param('game_id');
    my @player_names;
    eval { @player_names = $c->req->json->@* };
    if (@player_names) {
        $games->start($game_id, \@player_names, sub ($err, $result = undef) {
            if (defined $err) {
                $c->render(text => "blarg error: $err. talk to admin", status => 500);
            } else {
                $c->render(json => { success => 1 });
            }
        });
    } else {
        $c->render(json => { error => "invalid_json"});
    }
};

post '/games/:game_id/end' => sub ($c) {
    my $game_id = $c->param('game_id');
    $c->render(json => { success => 1 });
};

post '/:player_name/surviving_unit' => sub ($c) {
    my $player_name = $c->param('player_name');
    my $player_unit = $c->req->json;
    $units->check_in($player_name, $player_unit, sub ($err, $res = undef) {
        if (defined $err) {
            $c->render(json => {error => "$err"});
        } else {
            $c->render(json => {success => 1});
        }
    });
};

del '/:player_name/units/:hq_id' => sub ($c) {
    my $player_name = $c->param('player_name');
    my $hq_id = $c->param('hq_id');
    $units->remove($player_name, $hq_id, sub ($err, $res = undef) {
        if (defined $err) {
            $c->render(json => {error => "$err"});
        } else {
            $c->render(json => {success => 1});
        }
    });
};

app->start;
