# EREQINEOF and EREQINBUFLIMIT.
use warnings;
use strict;
use t::share;

@CheckPoint = (
    [ 'reader', 0, IO::Stream::EREQINEOF        ], 'reader: EREQINEOF',
    [ 'reader', 0, IO::Stream::EREQINBUFLIMIT   ], 'reader: EREQINBUFLIMIT',
    [ 'reader', IN, '123'                       ], 'reader: IN "123"',
);
plan tests => @CheckPoint/2;

pipe my $rd_pipe, my $wr_pipe or die "pipe: $!";
my $r = IO::Stream->new({
    fh          => $rd_pipe,
    cb          => \&reader,
    wait_for    => 0,
});
my $w = IO::Stream->new({
    fh          => $wr_pipe,
    cb          => \&writer,
    wait_for    => 0,
});

$w->write('1');
EV::loop;

$r->{wait_for} = EOF;
$w->write('2');
EV::loop;

$r->{wait_for} = IN;
$w->write('3');
EV::loop;


sub reader {
    my ($io, $e, $err) = @_;
    checkpoint($e, $err || $io->{in_buf});
    EV::unloop;
}

sub writer {
    my ($io, $e, $err) = @_;
    checkpoint($e, $err);
}


