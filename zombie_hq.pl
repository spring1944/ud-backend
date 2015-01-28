#!/usr/bin/env perl
use Mojolicious::Lite;
use 5.20.1;
use lib 'lib';
use experimental qw(signatures postderef);
use Data::Dumper qw(Dumper);
use Zombies::Schema qw();

my $schema = Zombies::Schema->connect('dbi:SQLite:db/zombies.db');
my $players = $schema->resultset('Player');
my $bank_accounts = $schema->resultset('BankAccount');
my $units = $schema->resultset('Unit');
my $games = $schema->resultset('Game');

get '/account/:player_name' => sub ($c) {
    my $player_name = $c->param('player_name');
    my $player = $players->find_or_create({
        handle => $player_name
    });
    $c->render(json => $player);
};

post '/bank/:player_name' => sub ($c) {
    my $player_name = $c->param('player_name');
    my $transaction = $c->req->json;
    say Dumper($transaction);
    my $player = $players->find({handle => $player_name});
    if ($player) {
        my $account = $bank_accounts->find_or_create({player_id => $player->id});
        my $current = $account->amount() // 0;
        $account->amount($current + int($transaction->{amount}));
        $account->update;
        $c->render(text => "ok");
    } else {
        $c->render(text => "no such player", status => 404);
    }
};

post '/start/:game_id' => sub ($c) {
    my $game_id = $c->param('game_id');
    my $player_names = $c->req->json;

    say Dumper($player_names);
    my $game = $games->find_or_create({
        spring_id => $game_id
    });
    $game->start_time(time);

    $c->render(text => "ok");
};

post '/end/:game_id' => sub ($c) {
    my $game_id = $c->param('game_id');
    my $game = $games->find({
        spring_id => $game_id
    });

    if ($game) {
        $game->end_time(time);
        $game->update;
        $c->render(text => 'ok');
    } else {
        $c->render(text => "no such game", status => 404);
    }
};

post '/army/:player_name' => sub ($c) {
    my $player_name = $c->param('player_name');
    my $player_unit = $c->req->json;
    say Dumper($player_unit);
    my $player = $players->find({handle => $player_name});
    my $unit = $units->find({ id => $player_unit->{hid}, player_id => $player->id });
    if ($unit) {
        $unit->update({
            health => $player_unit->{h},
            experience => $player_unit->{x},
            ammo => $player_unit->{a},
        });
    } else {
        # this shouldn't happen often - you don't get units during a game
        # (once webshop is implemented)
        $unit = $units->create({
            player_id => $player->id,
            ingame_name => $player_unit->{n},
            health => $player_unit->{h},
            experience => $player_unit->{x},
            ammo => $player_unit->{a},
        });
    }
    if ($unit) {
        $c->render(text => 'ok');
    } else {
        $c->render(text => 'did not create/update unit', status => 500);
    }
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
