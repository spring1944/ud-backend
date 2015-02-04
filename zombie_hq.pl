#!/usr/bin/env perl
use Mojolicious::Lite;
use 5.20.1;
use lib 'lib';
use experimental qw(signatures postderef);
use Data::Dumper qw(Dumper);
use Zombies::Db::Players;
my $players = Zombies::Players->new;

get '/account/:player_name' => sub ($c) {
    my $player_name = $c->param('player_name');
    $players->find_or_create($player_name => sub ($player, $err = undef) {
        $c->render(json => $player);
    });
};

post '/bank/:player_name' => sub ($c) {
    my $player_name = $c->param('player_name');
    my $transaction = $c->req->json;
    $players->bank_transaction($player_name, $transaction, sub ($new_amount, $err = undef) {
        if ($err) {
            $c->render(text => "blarg error", status => 500);
        } else {
            if (defined $new_amount) {
                $c->render(json => {success => 1});
            } else {
                $c->render(json => {error => "no such player"});
            }
        }
    });
};

post '/start/:game_id' => sub ($c) {
    my $game_id = $c->param('game_id');
    my @player_names;
    eval { @player_names = $c->req->json->@* };
    if (@player_names) {
        $players->start_game(\@player_names, sub ($result, $err = undef) {
            $c->render(text => "ok");
        });
    } else {
        $c->render(json => { error => "invalid_json"});
    }
};

post '/end/:game_id' => sub ($c) {
    my $game_id = $c->param('game_id');
};

post '/army/:player_name' => sub ($c) {
    my $player_name = $c->param('player_name');
    my $player_unit = $c->req->json;
    $players->check_in_unit($player_name, $player_unit, sub ($res) {
        if ($res) {
            $c->render(json => {success => 1});
        } else {
            $c->render(json => {error => "no such unit"});
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
