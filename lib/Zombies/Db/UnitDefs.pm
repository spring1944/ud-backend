package Zombies::Db::UnitDefs;
use Mojo::Base -base;
use Zombies::Db;
use Zombies::Logger qw(logger);
use Zombies::Util qw(error);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::IOLoop;
use 5.20.1;
use experimental qw(postderef signatures);

has pg => sub { Zombies::Db::handle() };

sub get_all_units($self, $cb) {
    my $sql = 'SELECT * FROM unitdef';
    $self->pg->db->query($sql, sub ($, $err, $results) {
        if (defined $err) {
            $cb->($err, undef);
        } else {
            my $units = $results->hashes->to_array;
            $cb->(undef, $units);
        }
    });
}

sub get_side_units($self, $side, $cb) {
    if (!defined $side) {
        $self->get_all_units($cb);
    } else {
        my $delay = Mojo::IOLoop->delay(
            sub ($delay) {
                my $sql = 'SELECT * FROM unitdef WHERE side = ? ORDER BY COST ASC';
                $self->pg->db->query($sql, $side, $delay->begin);
            },
            sub ($, $err, $results) {
                die { msg => "no such side: $side", sev => 0 } if $err;

                my $units = $results->hashes->to_array;
                $cb->(undef, $units);
            }
        )->catch(sub ($, $err) {
            error("fetching side units: $side", $err, $cb);
        })->wait;
    }
}

1;
