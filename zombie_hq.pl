#!/usr/bin/env perl
use Mojolicious::Lite;
use 5.20.1;
use lib 'lib';
use experimental qw(signatures postderef);
use Data::Dumper qw(Dumper);
use Zombies::Db::Players;
use Zombies::Db::Units;
use Zombies::Db::Games;
plugin 'basic_auth';

my $players = Zombies::Db::Players->new;
my $units = Zombies::Db::Units->new;
my $games = Zombies::Db::Games->new;

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

# buy unit
post '/:player_name/units/:unitdef' => sub ($c) {
    my $player_name = $c->param('player_name');
    my $unitdef = $c->param('unitdef');
    $units->buy($player_name, $unitdef, sub ($err, $remaining_money = undef) {
        if (defined $err) {
            $c->render(json => {error => "$err"});
        } else {
            $c->render(json => {balance => $remaining_money});
        }
    });
};

# sell unit
del '/:player_name/units/:unit_id' => sub ($c) {
    my $player_name = $c->param('player_name');
    my $unit_id = $c->param('unit_id');
    $units->sell($player_name, $unit_id, sub ($err, $new_account_balance = undef) {
        if (defined $err) {
            $c->render(json => {error => "$err"});
        } else {
            $c->render(json => {balance => $new_account_balance});
        }
    });
};


app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'UNDEAD RISING SHOP';

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
