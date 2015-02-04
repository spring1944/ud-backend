package Zombies::Db;
use strict;
use warnings;
use 5.20.1;
use Mojo::Pg;

sub handle { state $pg = Mojo::Pg->new('postgresql://postgres:foobar@localhost/zombies') }

1;
