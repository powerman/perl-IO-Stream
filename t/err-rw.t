# errors in sysread/syswrite
use warnings;
use strict;
use t::share;

@CheckPoint = (
    [ 'writer', 0, 'Broken pipe'            ], 'writer: Broken pipe',
    [ 'reader', 0, 'Bad file descriptor'    ], 'reader: Bad file descriptor',
);
plan tests => @CheckPoint/2;

socketpair my $server, my $client, AF_UNIX, SOCK_STREAM, PF_UNSPEC or die "socketpair: $!";
fcntl $server, F_SETFL, O_NONBLOCK                        or die "fcntl: $!";
fcntl $client, F_SETFL, O_NONBLOCK                        or die "fcntl: $!";

my $r = IO::Stream->new({
    fh          => $server,
    cb          => \&reader,
    wait_for    => 0,
});
close $server;

my $w = IO::Stream->new({
    fh          => $client,
    cb          => \&writer,
    wait_for    => 0,
});
$w->write('x' x 204800);
EV::loop;


sub writer {
    my ($io, $e, $err) = @_;
    checkpoint($e, $err);
    EV::unloop;
}

sub reader {
    my ($io, $e, $err) = @_;
    checkpoint($e, $err);
    EV::unloop;
}
