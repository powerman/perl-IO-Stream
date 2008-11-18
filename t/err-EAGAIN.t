# EAGAIN in sysread/syswrite
use warnings;
use strict;
use t::share;

@CheckPoint = (
    [ 'timeout_write'   ], 'force EAGAIN in syswrite',
    [ 'timeout_read'    ], 'force EAGAIN in sysread',
);
plan tests => @CheckPoint/2;

pipe my $rd_pipe, my $wr_pipe or die "pipe: $!";
fcntl $rd_pipe, F_SETFL, O_NONBLOCK                or croak qq{fcntl: $!};
fcntl $wr_pipe, F_SETFL, O_NONBLOCK                or croak qq{fcntl: $!};

my $timeout = $INC{'Devel/Cover.pm'} ? 2 : 0.5;
my ($r, $w, $t);
$w = IO::Stream->new({
    fh          => $wr_pipe,
    cb          => \&writer,
    wait_for    => OUT,
});
$w->write('x' x 204800);

EV::loop;


sub writer {
    my ($io, $e, $err) = @_;
    if ($e == OUT) {
        $t = EV::timer($timeout, 0, \&timeout_write);
    } else {
        checkpoint($e);
    }
}

sub reader {
    my ($io, $e, $err) = @_;
    if ($e == IN) {
        $t = EV::timer($timeout, 0, \&timeout_read);
    } else {
        checkpoint($e);
    }
}

sub timeout_write {
    checkpoint();
    EV::feed_fd_event(fileno($w->{fh}), EV::WRITE); # force EAGAIN in syswrite
    $r = IO::Stream->new({
        fh          => $rd_pipe,
        cb          => \&reader,
        wait_for    => IN,
    });
}

sub timeout_read {
    checkpoint();
    EV::feed_fd_event(fileno($r->{fh}), EV::READ);  # force EAGAIN in sysread
    $t = EV::timer($timeout, 0, sub { EV::unloop });
}

