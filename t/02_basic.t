#!/usr/bin/env perl

use strict;
use warnings;

use v5.10;

use Test::More tests => 7;
use Test::NoWarnings;
use Test::MockObject;

use lib "../lib";

use App::GitHub;
 
if ( not exists $ENV{COLUMNS} ) {
    $ENV{COLUMNS} = 80;
    $ENV{LINES}   = 24;
}

my $mock_ngh = Test::MockObject->new;
$mock_ngh->set_isa( "Net::GitHub" );

my $gh = App::GitHub->new( github => $mock_ngh );
isa_ok( $gh, "App::GitHub" );

is( $gh->prompt, "github> ", "Prompt is 'github> '" );
ok( defined $gh->term, "term defined" );
is( $gh->silent, 0, "Silent is false" );
is_deeply( $gh->_data, {}, "_data is empty" );
is_deeply( $gh->repo_regexp, qr/^([\-\w]+)[\/\\\s]([\-\w]+)$/, "repo_regexp is accurate" );
