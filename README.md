[![Build Status](https://travis-ci.org/powerman/perl-IO-Stream.svg?branch=master)](https://travis-ci.org/powerman/perl-IO-Stream)
[![Coverage Status](https://coveralls.io/repos/powerman/perl-IO-Stream/badge.svg?branch=master)](https://coveralls.io/r/powerman/perl-IO-Stream?branch=master)

# NAME

IO::Stream - ease non-blocking I/O streams based on EV

# VERSION

This document describes IO::Stream version v2.0.1

# SYNOPSIS

    use EV;
    use IO::Stream;

    IO::Stream->new({
        host        => 'google.com',
        port        => 80,
        cb          => \&client,
        wait_for    => SENT|EOF,
        in_buf_limit=> 102400,
        out_buf     => "GET / HTTP/1.0\nHost: google.com\n\n",
    });

    $EV::DIED = sub { warn $@; EV::unloop };
    EV::loop;

    sub client {
        my ($io, $e, $err) = @_;
        if ($err) {
            $io->close();
            die $err;
        }
        if ($e & SENT) {
            print "request sent, waiting for reply...\n";
        }
        if ($e & EOF) {
            print "server reply:\n", $io->{in_buf};
            $io->close();
            EV::unloop;         # ALL DONE
        }
    }

# DESCRIPTION

Non-blocking event-based low-level I/O is hard to get right. Code usually
error-prone and complex... and it very similar in all applications. Things
become much worse when you need to alter I/O stream in some way - use
proxies, encryption, SSL, etc.

This module designed to give user ability to work with I/O streams on
higher level, using input/output buffers (just scalars) and high-level
events like CONNECTED, SENT or EOF. As same time it doesn't hide low-level
things, and user still able to work on low-level without any limitations.

## PLUGINS

Architecture of this module make it ease to write plugins, which will alter
I/O stream in any way - route it through proxies, encrypt, log, etc.

Here are few available plugins, you may find more on CPAN:
[IO::Stream::Crypt::RC4](https://metacpan.org/pod/IO::Stream::Crypt::RC4),
[IO::Stream::Proxy::HTTPS](https://metacpan.org/pod/IO::Stream::Proxy::HTTPS),
[IO::Stream::MatrixSSL::Client](https://metacpan.org/pod/IO::Stream::MatrixSSL::Client),
[IO::Stream::MatrixSSL::Server](https://metacpan.org/pod/IO::Stream::MatrixSSL::Server).

If you interested in writing own plugin, check source for "skeleton"
plugins: [IO::Stream::Noop](https://metacpan.org/pod/IO::Stream::Noop) and [IO::Stream::NoopAlias](https://metacpan.org/pod/IO::Stream::NoopAlias).

# EXPORTS

This modules doesn't export any functions/methods/variables, but it exports
a lot of constants. There two groups of constants: events and errors
(which can be imported using tags ':Event' and ':Error').
By default all constants are exported.

Events:

    RESOLVED CONNECTED IN OUT EOF SENT

Errors:

    EINBUFLIMIT
    ETORESOLVE ETOCONNECT ETOWRITE
    EDNS EDNSNXDOMAIN EDNSNODATA
    EREQINBUFLIMIT EREQINEOF

Errors are similar to $! - they're dualvars, having both textual and numeric
values.

**NOTE:** Since v2.0.0 `ETORESOLVE`, `EDNSNXDOMAIN` and `EDNSNODATA` are
not used anymore (`EDNS` is used instead), but they're still exported for
compatibility.

# OVERVIEW

You can create IO::Stream object using any "stream" fh
(file, TTY, UNIX socket, TCP socket, pipe, FIFO).
Or, if you need TCP socket, you can create IO::Stream object using host+port
instead of fh (in this case IO::Stream will do non-blocking host resolving,
create TCP socket and do non-blocking connect).

After you created IO::Stream object, it will handle read/write on this fh,
and deliver only high-level events you asked for into your callback, where
you will be able to operate with in/out buffers instead of doing
sysread()/syswrite() manually.

There no limitations on what you can do with fh after you've created
IO::Stream object - you can even do sysread()/syswrite() (but there no
reasons for you to do this anymore).

**IMPORTANT!** When you want to close this fh,
**you MUST use $io->close() method for closing fh** instead of
doing close($fh). This is because IO::Stream doesn't require from you to
keep object returned by new(), and without call to $io->close()
IO::Stream object will continue to exists and may receive/generate some
events, which is not what you expect after closing fh. Also, if you keep
object returned by IO::Stream->new() somewhere in your variables, you
should either undef all such variables after you called $io->close(),
or you should use Scalar::Util::weaken() on these variables after storing
IO::Stream object. (The same is applicable for all plugin objects too.)

## EVENTS

- RESOLVED

    If you created IO::Stream object using {host}+{port} instead of {fh},
    this event will be generated after resolving {host}. Resolved IP address
    will be stored in {ip}.

- CONNECTED

    If you created IO::Stream object using {host}+{port} instead of {fh},
    this event will be generated after connecting socket to {ip}:{port}.

- IN

    Generated after each successful read. IO::Stream may execute several
    sysread() at once before generating IN event for optimization.
    Read data will be stored in {in\_buf}, and {in\_bytes} counter will be
    incremented by amount of bytes read.

- EOF

    Generated only **ONCE** when EOF reached (sysread() return 0).
    Also will set {is\_eof} to true.

- OUT

    Generated when some data from {out\_buf} was written. Written bytes either
    removed from {out\_buf} or just increment {out\_pos} by amount of bytes written
    (see documentation about these fields below for more details).
    Also increment {out\_bytes} counter by amount of bytes written.

    Here 'written' may be somewhat virtual, while {out\_buf}/{out\_pos} changes,
    the real data still can be in plugin buffers (if you use plugins) and real
    syswrite() may not be called yet. To detect when all data is **really**
    written you should use SENT event, not OUT.

- SENT

    Generated when all data from {out\_buf} was written. It's usual and safe to
    call $io->close() on SENT event.

## TIMEOUTS

IO::Stream has 30-second timeouts for connect and write,
to timeout DNS resolve it use default AnyEvent::DNS timeout.
If you need to timeout other operations, you have to create own timers
using EV::timer().

Current version doesn't allow you to change these timeouts.

## SERVER

If you need to run TCP/UNIX-server socket, then you should handle that socket
manually. But you can create IO::Stream object for accept()'ed socket:

    my ($host, $port) = ('0.0.0.0', 1234);
    socket  my $srv_sock, AF_INET, SOCK_STREAM, 0;
    setsockopt $srv_sock, SOL_SOCKET, SO_REUSEADDR, 1;
    bind       $srv_sock, sockaddr_in($port, inet_aton($host));
    listen     $srv_sock, SOMAXCONN;
    fcntl      $srv_sock, F_SETFL, O_NONBLOCK;
    $srv_w = EV::io($srv_sock, EV::READ, sub {
        if (accept my $sock, $srv_sock) {
            IO::Stream->new({
                fh          => $sock,
                cb          => \&server,
                wait_for    => IN,
            });
        }
        elsif ($! != EAGAIN) {
            die "accept: $!";
        }
    });

# INTERFACE 

IO::Stream provide only three public methods: new(), write() and close().
new() will create new object, close() will destroy it and write() must be
called when you want to modify (or just modified) output buffer.

All other operations are done using IO::Stream object fields - for
simplicity and performance reasons. Moreover, you can keep your own data
in it. There convention on field names, to avoid conflicts:

- /^\_/

    Fields with names started with underscore are for internal use by
    IO::Stream, you shouldn't touch them or create your own field with such
    names.

- /^\[a-z\]/

    Fields with names started with lower-case letter are part of IO::Stream
    public interface - you allowed to read/write these fields, but you should
    not store incorrect values in these fields. Check ["PUBLIC FIELDS"](#public-fields) below
    for description of available fields and their format.

- /^\[A-Z\]/

    You can store your own data in IO::Stream object using field names started
    with upper-case letter. IO::Stream will not touch these fields.

When some event arise which you're waited for, your callback will be
called with 3 parameters: IO::Stream object, event mask, and error (if any):

    sub callback {
        my ($io, $e, $err) = @_;
    }

# METHODS

## new

    IO::Stream->new( \%opt );

Create and return IO::Stream object. You may not keep returned object - you
will get it in your callback (in first parameter) when some interesting
for your event happens, and will exists until to call method close().
See [OVERVIEW](https://metacpan.org/pod/OVERVIEW) for more details.

Fields of %opt become fields of created IO::Stream object. There only few
fields required, but you can set any other fields too, and can also set
your custom fields (with names starting from upper-case letter).

Only required fields in %opt are {cb} and either {fh} or {host}+{port}.
The {wait\_for} field also highly recommended to set when creating object.

If {out\_buf} will be set, then new() will automatically call write() after
creating object.

    IO::Stream->new({
        fh          => \*STDIN,
        cb          => \&console,
        wait_for    => IN,
    });

## write

    $io->write();
    $io->write($data);

Method write() **MUST** be called after any modifications of {out\_buf} field,
to ensure data in {out\_buf} will be written to {fh} as soon as it will be
possible.

If {fh} available for writing when calling write(), then it will write
(may be partially) {out\_buf} and may immediately call your callback function
delivering OUT|SENT events there. So, if you call write() from that callback
(as it usually happens), keep in mind it may be called again while executing
write(), and object state may significantly change (it even may be close()'d)
after it return from write() into your callback.

The write($data) is just a shortcut for:

    $io->{out_buf} .= $data;
    $io->write();

## close

    $io->close()

Method close() will close {fh} and destroy IO::Stream object.
See [OVERVIEW](https://metacpan.org/pod/OVERVIEW) for more details.

# PUBLIC FIELDS

If field marked \*RO\* that mean field is read-only and shouldn't be changed.

Some field have default values (shown after equal sign).

Some field modified on events.

- cb
- method ='IO'

    User callback which will be called when some listed in {wait\_for} events
    arise or error happens.

    Field {cb} should be either CODE ref or object or class name. In last two
    cases method named {method} will be called. Field {method} should be string.

- wait\_for

    Bitmask of events interesting for user. Can be changed at any time.
    For example:

        $io->{wait_for} = RESOLVED|CONNECTED|IN|EOF|OUT|SENT;

    When some data will be read from {fh}, {wait\_for} must contain IN and/or EOF,
    or error EREQINEOF will be generated. So, it's better to always have
    IN and/or EOF in {wait\_for}.

    If {wait\_for} contain EOF and doesn't contain IN then {in\_buf\_limit} must
    be defined or error EREQINBUFLIMIT will be generated.

- fh \*RO\*

    File handle for doing I/O. It's either provided by user to new(), or created
    by new() (when user provided {host}+{port} instead).

- host \*RO\*
- port \*RO\*

    If user doesn't provide {fh} to new(), he should provide {host} and {port}
    instead. This way new() will create new TCP socket in {fh} and resolve
    {host} and connect this {fh} to resolved {ip} and {port}. Both resolving
    and connecting happens in non-blocking way, and will result in delivering
    RESOLVED and CONNECTED events into user callback (if user {wait\_for} these
    events).

- in\_buf\_limit =undef

    Used to avoid DoS attach when user doesn't handle IN events and want his
    callback called only on EOF event. Must be defined if user have EOF without
    IN in {wait\_for}.

    Any value >0 will defined amount of bytes which can be read into {in\_buf}
    before EOF happens. When size of {in\_buf} become larger than {in\_buf\_limit},
    error EINBUFLIMIT will be delivered to user callback. In this case user can
    either remove some data from {in\_buf} to make it smaller than {in\_buf\_limit}
    or increase {in\_buf\_limit}, and continue reading data.

    **NOT RECOMMENDED!** Value 0 will switch off DoS protection, so there will
    be no limit on amount of data to read into {in\_buf} until EOF happens.

- out\_buf =q{}          # modified on: OUT
- out\_pos =undef        # modified on: OUT

    Data from {out\_buf} will be written to {fh}.

    If {out\_pos} not defined, then data will be written from beginning of
    {out\_buf}, and after successful write written bytes will be removed from
    beginning of {out\_buf}.

    If {out\_pos} defined, it should be >= 0. In this case data will be written
    from {out\_pos} position in {out\_buf}, and after successful write {out\_pos}
    will be incremented by amount of bytes written. {out\_buf} will not be changed!

- out\_bytes =0          # modified on: OUT

    Each successful write will increment {out\_bytes} by amount of written bytes.
    You can change {out\_bytes} in any way, but it should always be a number.

- in\_buf =q{}           # modified on: IN

    Each successful read will concatenate read bytes to {in\_buf}.
    You can change {in\_buf} in any way, but it should always be a string.

- in\_bytes =0           # modified on: IN

    Each successful read will increment {in\_bytes} by amount of read bytes.
    You can change {in\_bytes} in any way, but it should always be a number.

- ip \*RO\* =undef        # modified on: RESOLVED

    When you call new() with {host}+{port} instead of {fh} then IP address
    resolved from {host} will be stored in {ip}, and event RESOLVED will be
    generated.

- is\_eof \*RO\* =undef    # modified on: EOF

    When EOF event happens {is\_eof} will be set to true value.
    This allow you to detect is EOF already happens at any time, even if
    you doesn't have EOF in {wait\_for}.

- plugin \*RO\* ={}

    Allow you to set list of plugins when creating object with new(),
    and later access these plugins.

    This field is somewhat special, because when you call new() you should
    set plugin to ARRAY ref, but in IO::Stream object {plugin} is HASH ref:

        my $io = IO::Stream->new({
            host        => 'www.google.com',
            port        => 443,
            cb          => \&google,
            wait_for    => EOF,
            in_buf_limit=> 102400,
            out_buf     => "GET / HTTP/1.0\nHost: www.google.com\n\n",
            plugin      => [    # <------ it's ARRAY, but looks like HASH
                ssl         => IO::Stream::MatrixSSL::Client->new(),
                proxy       => IO::Stream::Proxy::HTTPS->new({
                    host        => 'my.proxy.com',
                    port        => 3218,
                    user        => 'me',
                    pass        => 'my pass',
                }),
            ],
            MyField1    => 'my data1',
            MyField2    => \%mydata2,
        });

        # access the "proxy" plugin:
        $io->{plugin}{proxy};

    This is because when calling new() it's important to keep plugins in order,
    but later it's easier to access them using names.

# DIAGNOSTICS

Exceptions may be thrown only in new(). All other errors will be delivered
to user's callback in last parameter.

- `usage: IO::Stream->new({ cb=>, wait_for=>, [fh=>, | host=>, port=>,] ... })`

    You called new() with wrong parameters.

- `socket: %s`
- `fcntl: %s`

    Error happens while creating new socket. Usually this happens because you
    run out of file descriptors.

- `can't get file descriptor`

    Failed to get fileno() for your fh. Either fh doesn't open, or this fh
    type is not supported (directory handle), or fh is not file handle at all.

- `can't create second object for same fh`

    You can't have more than one IO::Stream object for same fh.

    IO::Stream keep all objects created by new() until $io->close() will be
    called. Probably you've closed fh in some way without calling
    $io->close(), then new fh was created with same file descriptor
    number, and you've tried to create IO::Stream object using new fh.

# SEE ALSO

[AnyEvent::Handle](https://metacpan.org/pod/AnyEvent::Handle)

# SUPPORT

## Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at [https://github.com/powerman/perl-IO-Stream/issues](https://github.com/powerman/perl-IO-Stream/issues).
You will be notified automatically of any progress on your issue.

## Source Code

This is open source software. The code repository is available for
public review and contribution under the terms of the license.
Feel free to fork the repository and submit pull requests.

[https://github.com/powerman/perl-IO-Stream](https://github.com/powerman/perl-IO-Stream)

    git clone https://github.com/powerman/perl-IO-Stream.git

## Resources

- MetaCPAN Search

    [https://metacpan.org/search?q=IO-Stream](https://metacpan.org/search?q=IO-Stream)

- CPAN Ratings

    [http://cpanratings.perl.org/dist/IO-Stream](http://cpanratings.perl.org/dist/IO-Stream)

- AnnoCPAN: Annotated CPAN documentation

    [http://annocpan.org/dist/IO-Stream](http://annocpan.org/dist/IO-Stream)

- CPAN Testers Matrix

    [http://matrix.cpantesters.org/?dist=IO-Stream](http://matrix.cpantesters.org/?dist=IO-Stream)

- CPANTS: A CPAN Testing Service (Kwalitee)

    [http://cpants.cpanauthors.org/dist/IO-Stream](http://cpants.cpanauthors.org/dist/IO-Stream)

# AUTHOR

Alex Efros &lt;powerman@cpan.org>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2008- by Alex Efros &lt;powerman@cpan.org>.

This is free software, licensed under:

    The MIT (X11) License
