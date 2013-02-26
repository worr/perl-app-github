#!/usr/bin/env perl

use strict;
use warnings;

use v5.10;

use Test::More;
use IO::Scalar;

use lib "t/lib";

use App::GitHub;
use App::GitHub::Test qw/init_app_github/;

my $gh = init_app_github;
my $input = "test\ntest\n";
my $test_prompt = "perl-App-GitHub> ";
my $io = IO::Scalar->new( \$input );

# test gh->read default prompt

local *STDIN = $io;
is( $gh->read, "test" );
is( ($gh->term->call_args( 1 ))[1], $gh->prompt );
$gh->term->clear;

is( $gh->read( $test_prompt ), "test" );
is( ($gh->term->call_args( 1 ))[1], $test_prompt );
$gh->term->clear;

done_testing;
