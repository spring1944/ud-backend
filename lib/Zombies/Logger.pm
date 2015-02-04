package Zombies::Logger;
use strict;
use warnings;
use 5.20.1;
use Mojo::Log;

sub logger { state $log = Mojo::Log->new(path => 'logs/error.log') }

1;
