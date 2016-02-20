requires 'perl', '5.010001';

requires 'EV';
requires 'EV::ADNS';
requires 'Scalar::Util';
requires 'Socket';
recommends 'Data::Alias', '0.08';

on configure => sub {
    requires 'Module::Build::Tiny', '0.034';
};

on test => sub {
    requires 'File::Temp';
    requires 'Test::Exception';
    requires 'Test::More';
};

on develop => sub {
    requires 'Test::Distribution';
    requires 'Test::Perl::Critic';
};
