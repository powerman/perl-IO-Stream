# errors in sysread/syswrite
use warnings;
use strict;
use t::share;

@CheckPoint = (
    {
	win32 => [
	    [ 'reader', 0, EBADF		    ], 'reader: Bad file descriptor',
	    {
		unknown => [
		    [ 'writer', 0, 'Unknown error'  ], 'writer: Unknown error',
		],
		aborted => [
		    [ 'writer', 0, ECONNABORTED     ], 'writer: established connection was aborted',
		],
	    },
	    [ 'writer', 0, EBADF		    ], 'writer: Bad file descriptor',
	],
	other => [
	    [ 'writer', 0, EPIPE		    ], 'writer: Broken pipe',
	    [ 'writer', 0, EBADF		    ], 'writer: Bad file descriptor',
	    [ 'reader', 0, EBADF		    ], 'reader: Bad file descriptor',
	],
    },
);
plan tests => checkpoint_count();

socketpair my $server, my $client, AF_UNIX, SOCK_STREAM, PF_UNSPEC or die "socketpair: $!";
nonblocking($server);
nonblocking($client);

my $r = IO::Stream->new({
    fh		=> $server,
    cb		=> \&reader,
    wait_for	=> 0,
});
close $server;

my $w = IO::Stream->new({
    fh		=> $client,
    cb		=> \&writer,
    wait_for	=> 0,
});
$w->write('x' x 204800);
EV::loop;
EV::loop;


sub writer {
    my ($io, $e, $err) = @_;
    checkpoint($e, 0+$err);
    $io->close();
    EV::unloop;
}

sub reader {
    my ($io, $e, $err) = @_;
    checkpoint($e, 0+$err);
    $io->close();
    EV::unloop;
}
