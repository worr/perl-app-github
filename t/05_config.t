#!/usr/bin/env perl

use strict;
use warnings;

use v5.10;

use Test::More tests => 8;
use Test::MockCommand playback => 't/db/05_config.db';
use Test::NoWarnings;

use lib 't/lib';

use App::GitHub::Test qw/init_app_github/;

my $gh = init_app_github;

ok( $gh->set_loadcfg );
is( $gh->{_data}->{login}, "worr" );
is( $gh->{_data}->{pass}, "test" );

my ( $user_cmd ) = Test::MockCommand->find( command => 'git config --global github.user' );
my ( $pass_cmd ) = Test::MockCommand->find( command => 'git config --global github.pass' );

ok( $user_cmd );
ok( $pass_cmd );
is( $user_cmd->return_value(), "worr\n" );
is( $pass_cmd->return_value(), "test\n" );
