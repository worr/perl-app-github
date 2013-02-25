#!/usr/bin/env perl

use strict;
use warnings;

use v5.10;

use Test::More tests => 7;
use Test::NoWarnings;
use Test::MockObject;

use lib "../lib";

use App::GitHub;

my $mock_ngh = Test::MockObject->new;
$mock_ngh->set_isa( "Net::GitHub" );

my $gh = App::GitHub->new( github => $mock_ngh, term => \*STDOUT );
isa_ok( $gh, "App::GitHub" );

is( $gh->prompt, "github> ", "Prompt is 'github> '" );
isa_ok( $gh->term, "GLOB" );
is( $gh->silent, 0, "Silent is false" );
is_deeply( $gh->_data, {}, "_data is empty" );
is_deeply( $gh->repo_regexp, qr/^([\-\w]+)[\/\\\s]([\-\w]+)$/, "repo_regexp is accurate" );

