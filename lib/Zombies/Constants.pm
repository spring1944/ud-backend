package Zombies::Constants;
use strict;
use warnings;
use 5.20.1;

use Exporter qw(import);
our @EXPORT_OK = qw(
    STARTING_MONEY
    SELL_PENALTY
);

use constant STARTING_MONEY => 100_000;
use constant SELL_PENALTY => 0.05;

1;
