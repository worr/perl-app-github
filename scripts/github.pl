#!/usr/bin/perl

package  # hidden from PAUSE
  github;

# ABSTRACT: GitHub Command Tools

use strict;
use warnings;

use App::GitHub;

use Getopt::Long;
Getopt::Long::Configure("bundling");

use 5.010;

if (@ARGV == 0) {
    App::GitHub->new->run(@ARGV);
} else {
    # Let's define some options!
    my ($create, $username, $password);
    GetOptions(
        'create|c=s'        => \$create,
        'username|u=s'      => \$username,
        'password|p=s'      => \$password
    );

    my $github = App::GitHub->new( silent => 1 );

    unless ($username and $password) {
        $github->set_loadcfg;
    } else {
        $github->set_login("$username $password");
    }

    if ($create) {
        eval {
            $github->repo_create($create);
        };

        if ($@) {
            die "Could not create repo $create";
        } else {
            say "Created repo $create";
        }
    }
}

1;
