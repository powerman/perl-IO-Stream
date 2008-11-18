# Connect timeout (Looks like Google DROP incoming packets on port 21.)
use warnings;
use strict;
use IO::Stream::const ();
BEGIN {
    *IO::Stream::const::TOCONNECT   = sub () { 0.1 };
}
use t::share;

if (CFG_ONLINE ne 'y') {
    plan skip_all => 'online tests disabled';
}


@CheckPoint = (
    [ 'client',     RESOLVED, undef        ], 'client: RESOLVED',
    [ 'client',     0, 'connect timeout'   ], 'client: connect timeout',
);
plan tests => @CheckPoint/2;



IO::Stream->new({
    host        => 'google.com',
    port        => 21,
    cb          => \&client,
    wait_for    => RESOLVED|CONNECTED,
});

EV::loop;


sub client {
    my ($io, $e, $err) = @_;
    checkpoint($e, $err);
    EV::unloop if $err;
}

