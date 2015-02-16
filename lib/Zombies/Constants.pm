package Zombies::Constants;
use strict;
use warnings;
use 5.20.1;

use Exporter qw(import);
our @EXPORT_OK = qw(
    STARTING_MONEY
    SELL_PENALTY
    MIN_ARMY_SIZE
);

use constant STARTING_MONEY => 70_000;
use constant SELL_PENALTY => 0.05;
use constant MIN_ARMY_SIZE => 5;

1;
