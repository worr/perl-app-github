#!/usr/bin/env perl

use strict;
use warnings;

use v5.10;

use Test::More;
use Test::NoWarnings;
use Test::MockObject;
use Test::MockCommand record => 'commands.db';

use lib "../lib";
use lib "t/lib";
use lib "./lib";

use App::GitHub;
use App::GitHub::Test qw/init_app_github/;

my $gh = init_app_github;

{
    # Test normal printing
    local *STDOUT;
    my $output;
    open( STDOUT, '>', \$output );
    $gh->print( "testing" );
    is( $output, "testing\n" );
    close STDOUT;

    # test printer errors
    open( STDOUT, '>', \$output );
    $gh->print_err("error");
    is( $output, "error\n" );
    close STDOUT;
    
    # test that pager gets called correctly
    open( STDOUT, '>', \$output );
    local $ENV{PAGER} = "more";
    is( $gh->_get_pager, "more", "testing pager is more" );
    $gh->print( "really\nlong\ncommand\nto\ncall\nless" );
    my ( $more ) = Test::MockCommand->find( command => 'more' );
    ok( $more, "test that more was called" );
    delete local $ENV{PAGER};
    close STDOUT;
    
    # test that no pager errors gracefully
    open( STDOUT, '>', \$output );
    local $ENV{PATH} = ""; # disable use of pager
    $gh->print( "really\nlong\ncommand\nto\ncall\nless" );
    like( $output, 
          qr'no pager found at .+\nreally\nlong\ncommand\nto\ncall\nless', 
          "long output without pager fails gracefully" );
    close STDOUT;
}

done_testing;
