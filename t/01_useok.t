#!/usr/bin/env perl

use strict;
use warnings;

use v5.10;

use Test::More tests => 2;
use Test::NoWarnings;

use lib "../lib";

BEGIN { use_ok( "App::GitHub" ); }
