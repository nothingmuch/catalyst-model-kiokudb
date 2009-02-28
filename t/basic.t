#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use lib 't/lib';

use Catalyst::Test qw(Catalyst::Model::KiokuDB::Test);

my $log = Catalyst::Model::KiokuDB::Test->log;

$log->clear;

{
    request('/insert');

    like $log->str, qr/Loaded 2 objects/, "loaded count";
    unlike $log->str, qr/leaked/, "no leaks";

    $log->clear;
}

{
    request('/fetch');

    like $log->str, qr/Loaded 1 object/, "loaded count";
    unlike $log->str, qr/leaked/, "no leaks";

    $log->clear;
}

{
    request('/leak');

    like $log->str, qr/Loaded 1 object/, "loaded count";
    like $log->str, qr/leaked/, "no leaks";

    $log->clear;
}

{
    request('/fresh');

    like $log->str, qr/Loaded 1 object/, "loaded count";
    unlike $log->str, qr/leaked/, "no leaks";

    $log->clear;
}

{
    request('/login');

    like $log->str, qr/Loaded 1 object/, "loaded count";
    unlike $log->str, qr/leaked/, "no leaks";

    $log->clear;
}

is( $Catalyst::Model::KiokuDB::Test::Controller::Root::ran, 5, "tests ran successfully" );

