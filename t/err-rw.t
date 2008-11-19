# errors in sysread/syswrite
use warnings;
use strict;
use t::share;

@CheckPoint = (
(WIN32 ? (
    [ 'reader', 0, 'Bad file descriptor'    ], 'reader: Bad file descriptor',
    [ 'writer', 0, 'Unknown error'          ], 'writer: Unknown error',
    [ 'writer', 0, 'Bad file descriptor'    ], 'writer: Bad file descriptor',
) : (
    [ 'writer', 0, 'Broken pipe'            ], 'writer: Broken pipe',
    [ 'writer', 0, 'Bad file descriptor'    ], 'writer: Bad file descriptor',
    [ 'reader', 0, 'Bad file descriptor'    ], 'reader: Bad file descriptor',
)),
);
plan tests => @CheckPoint/2;

socketpair my $server, my $client, AF_UNIX, SOCK_STREAM, PF_UNSPEC or die "socketpair: $!";
nonblocking($server);
nonblocking($client);

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
EV::loop;


sub writer {
    my ($io, $e, $err) = @_;
    checkpoint($e, $err);
    $io->close();
    EV::unloop;
}

sub reader {
    my ($io, $e, $err) = @_;
    checkpoint($e, $err);
    $io->close();
    EV::unloop;
}
