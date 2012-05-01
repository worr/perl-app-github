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
    my ($create, $username, $password, $key, $name, $fork);
    GetOptions(
        'create|c=s'        => \$create,
        'key|k=s'           => \$key,
        'name|n=s'          => \$name,
        'fork|f=s'          => \$fork,
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
            say STDERR "Could not create repo $create";
            print STDERR $@;
        } else {
            say "Created repo $create";
        }
    } elsif ($key) {
        say STDERR "Provide a name for the key with -n" if not $name;

        eval {
            $github->user_pub_keys("add", $name, $key);
        };

        if ($@) {
            say STDERR "Could not add key";
            print STDERR $@;
        } else {
            say "Added pubkey";
        }
    } elsif ($fork) {
        eval {
            $github->run_basic_repo_cmd( 'repos', 'create_fork', $fork);
        };

        if ($@) {
            say STDERR "Could not fork $fork";
            print STDERR $@;
        } else {
            say "Forked repo $fork";
        }
    }
}

1;
