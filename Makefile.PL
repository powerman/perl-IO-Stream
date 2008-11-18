use inc::Module::Install;

name     'IO-Stream';
all_from 'lib/IO/Stream.pm';
author   'Alex Efros <powerman-asdf@ya.ru>';
license  'perl';

requires 'version';
requires 'EV';
requires 'EV::ADNS';

test_requires 'Test::More';
test_requires 'Test::Exception';
test_requires 'Data::Alias'     => '0.08';

my $online = prompt 'Run tests which require internet connection', 'n';
$online = lc $online eq 'y' ? 'y' : 'n';
open my $f, '>', 't/config.pm' or die "open: $!";
printf {$f} "use constant CFG_ONLINE => '%s';\n", $online;
printf {$f} '1;';
close $f or die "close: $!";

WriteAll;

