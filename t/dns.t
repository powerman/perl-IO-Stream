# DNS error.
use warnings;
use strict;
use t::share;

plan tests => 1;

IO::Stream->new({
    host        => 'no.such.host',
    port        => 80,
    cb          => \&client,
    wait_for    => IN,
});

EV::loop;

sub client {
    my ($io, $e, $err) = @_;
    is($err, IO::Stream::EDNSNXDOMAIN, 'no such host');
    EV::unloop;
}

