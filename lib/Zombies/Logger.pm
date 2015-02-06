package Zombies::Logger;
use strict;
use warnings;
use 5.20.1;
use Mojo::Log;

use Exporter qw(import);
our @EXPORT_OK = qw( logger );

sub logger { state $log = Mojo::Log->new(path => 'logs/error.log') }

1;
