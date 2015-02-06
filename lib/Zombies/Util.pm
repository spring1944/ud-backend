package Zombies::Util;
use 5.20.1;
use Zombies::Logger qw(logger);
use experimental qw(postderef signatures);

use Exporter qw(import);
our @EXPORT_OK = qw(error);

sub error($context, $error, $cb) {
    my $message = ref $error ? $error->{msg} : $error;
    if (!ref $error or $error->{sev} > 0) {
        logger()->error("$context: $message");
    }
    $cb->($message);
}

1;
