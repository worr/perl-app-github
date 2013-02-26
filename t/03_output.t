#!/usr/bin/env perl

use strict;
use warnings;

use v5.10;

use IO::CaptureOutput qw/capture/;
use Test::More tests => 6;
use Test::NoWarnings;
use Test::MockCommand record => 'commands.db';

use lib "t/lib";

use App::GitHub::Test qw/init_app_github/;

my $gh = init_app_github;
my $output;

# Test normal printing

capture { $gh->print( "testing" ) } \$output, undef;
is( $output, "testing\n" );

# test printer errors
capture { $gh->print_err("error") } \$output, undef;
is( $output, "error\n" );

# test that pager gets called correctly
{
    local $ENV{PAGER} = "more";
    is( $gh->_get_pager, "more", "testing pager is more" );
    capture { $gh->print( "really\nlong\ncommand\nto\ncall\nless" ) } undef, undef;
    my ( $more ) = Test::MockCommand->find( command => 'more' );
    ok( $more, "test that more was called" );
}

# test that no pager errors gracefully
{
    delete local $ENV{PATH}; # disable use of pager
    local $^W = 0 if $IPC::Cmd::VERSION <= 0.78; # https://github.com/jib/ipc-cmd/pull/2
    capture { $gh->print( "really\nlong\ncommand\nto\ncall\nless" ) } \$output, undef;
};

like( $output, 
      qr'no pager found at .+\nreally\nlong\ncommand\nto\ncall\nless', 
      "long output without pager fails gracefully" );
