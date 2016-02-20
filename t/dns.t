# DNS error.
use warnings;
use strict;
use t::share;

plan tests => 1;

IO::Stream->new({
    host        => 'no.such.host.q1w2e3',
    port        => 80,
    cb          => \&client,
    wait_for    => IN,
});

EV::loop;

sub client {
    my ($io, $e, $err) = @_;
    # sometimes test fail because we got 'Connection reset by peer' instead
    is($err, IO::Stream::EDNS, 'no such host');
    EV::unloop;
}

