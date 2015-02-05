#!/usr/bin/env perl
use Mojolicious::Lite;
use 5.20.1;
use lib 'lib';
use experimental qw(signatures postderef);
use Data::Dumper qw(Dumper);
use Zombies::Db::Players;
my $players = Zombies::Players->new;

get '/:player_name' => sub ($c) {
    my $player_name = $c->param('player_name');
    $players->find_or_create($player_name => sub ($player, $err = undef) {
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
    $players->bank_transaction($player_name, $transaction, sub ($new_amount, $err = undef) {
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

post '/games/:game_id/start' => sub ($c) {
    my $game_id = $c->param('game_id');
    my @player_names;
    eval { @player_names = $c->req->json->@* };
    if (@player_names) {
        $players->start_game($game_id, \@player_names, sub ($result, $err = undef) {
            if ($err) {
                $c->render(text => "blarg error. talk to admin", status => 500);
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
};

post '/:player_name/surviving_unit' => sub ($c) {
    my $player_name = $c->param('player_name');
    my $player_unit = $c->req->json;
    $players->check_in_unit($player_name, $player_unit, sub ($res) {
        if ($res) {
            $c->render(json => {success => 1});
        } else {
            $c->render(json => {error => "no_such_unit"});
        }
    });
};

post '/:player_name/units/:unitdef' => sub ($c) {
    my $player_name = $c->param('player_name');
    my $unitdef = $c->param('unitdef');
    $players->buy_unit($player_name, $unitdef, sub ($success, $remaining_money, $err = undef) {
        if ($success) {
            $c->render(json => {balance => $remaining_money});
        } else {
            $c->render(json => {error => "not_enough_command"});
        }
    });
};

post '/:player_name/units/sell/:unit_id' => sub ($c) {
    my $player_name = $c->param('player_name');
    my $unit_id = $c->param('unit_id');
    $players->sell_unit($player_name, $unit_id, sub ($success, $new_account_balance, $err = undef) {
        if ($success) {
            $c->render(json => {balance => $new_account_balance});
        } else {
            $c->render(json => {error => "no_such_unit"});
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
