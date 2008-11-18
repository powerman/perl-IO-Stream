# DNS error.
use warnings;
use strict;
use t::share;

# cover code which process stale ADNS replies on closed streams
IO::Stream->new({
    host        => "no_such_host_$$.com",
    port        => 80,
    cb          => \&client,
    wait_for    => IN,
})->close();

IO::Stream->new({
    host        => 'no.such.host',
    port        => 80,
    cb          => \&client,
    wait_for    => IN,
});

plan tests => 1;

EV::loop;

sub client {
    my ($io, $e, $err) = @_;
    is($err, IO::Stream::EDNSNXDOMAIN, 'no such host');
    EV::unloop;
}

