package App::GitHub;

use strict;
use warnings;

# ABSTRACT: GitHub Command Tools

use Moose;
use Net::GitHub;
use Term::ReadKey;
use Term::ReadLine;
use JSON::XS;
use IPC::Cmd qw/can_run/;

our $VERSION = '0.12';

has 'term' => (
    is => 'rw', required => 1,
    default => sub { Term::ReadLine->new('Perl-App-GitHub') }
);
has 'prompt' => (
    is => 'rw', required => 1,
    default => sub { 'github> ' }
);

has 'out_fh' => (
    is => 'rw', required => 1, lazy => 1,
    default => sub {
        shift->term->OUT || \*STDOUT;
    }
);

has 'repo_regexp' => (
    is => 'ro', required => 1,
    isa => 'RegexpRef',
    default => sub { qr/^([\-\w]+)[\/\\\s]([\-\w]+)$/ }
);

sub print {
    my ($self, $message) = @_;

    my $fh; local $@;
    my $rows = (GetTerminalSize($self->out_fh))[1];
    my $message_rows = $message =~ tr/\n/\n/;
    my $pager_use = 0;

    # let less exit if one screen
    no warnings 'uninitialized';
    local $ENV{LESS} ||= "";
    $ENV{LESS} .= " -F";
    use warnings;

    if ($@ or $message_rows < $rows) {
        $fh = $self->out_fh;
    } else {
        eval { open $fh, '|-', $self->_get_pager or die "unable to open more: $!" }
            or $fh = $self->out_fh;
        $pager_use = 1;
    }
    
    no warnings 'uninitialized';
    print $fh "$message";
    print $fh "\n" if $self->term->ReadLine =~ /Gnu/;
    close($fh) if $pager_use;
}

sub _get_pager {
    my $pager = $ENV{PAGER} || can_run("less") || can_run("more")
        || die "no pager found";
}

sub read {
    my ($self, $prompt) = @_;
    $prompt ||= $self->prompt;
    return $self->term->readline($prompt);
}

has 'github' => (
    is  => 'rw',
    isa => 'Net::GitHub',
);

has '_data' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

=head1 SYNOPSIS
 
    $ github.pl

     command   argument          description
     repo      :user :repo       set owner/repo, eg: 'fayland perl-app-github'
     login     :login :token     authenticated as :login
     loadcfg                     authed by git config --global github.user|token
     ?,h                         help
     q,exit,quit                 exit
    
    Repos
     r.show                      more in-depth information for the :repo
     r.list                      list out all the repositories for the :user
     r.watch                     watch repositories (auth required)
     r.unwatch                   unwatch repositories (auth required)
     r.fork                      fork a repository (auth required)
     r.create                    create a new repository (auth required)
     r.set_private               set a public repo private (auth required)
     r.set_public                set a private repo public (auth required)
    
    Issues
     i.list    open|closed       see a list of issues for a project
     i.view    :number           get data on an individual issue by number
     i.open                      open a new issue (auth required)
     i.close   :number           close an issue (auth required)
     i.reopen  :number           reopen an issue (auth required)
     i.edit    :number           edit an issue (auth required)
     i.comment :number
     i.label   add|del :num :label
                                 add/remove a label (auth required)
    
    Users
     u.show                      get extended information on user
     u.update                    update your users info (auth required)
     u.followers
     u.following
     u.follow  :user             follow :user (auth required)
     u.unfollow :user            unfollow :user (auth required)
     u.pub_keys                  Public Key Management (auth required)
     u.pub_keys.add
     u.pub_keys.del :number
    
    Commits
     c.branch  :branch           list commits for a branch
     c.file    :branch :file     get all the commits modified the file
     c.file    :file             (default branch 'master')
     c.show    :sha1             show a specific commit
    
    Objects
     o.tree    :tree_sha1        get the contents of a tree by tree sha
     o.blob    :tree_sha1 :file  get the data of a blob by tree sha and path
     o.raw     :sha1             get the data of a blob (tree, file or commits)
    
    Others
     r.show    :user :repo       more in-depth information for a repository
     r.list    :user             list out all the repositories for a user
     u.show    :user             get extended information on :user

=head1 DESCRIPTION

A command-line wrapper for L<Net::GitHub>

Repository: L<http://github.com/worr/perl-app-github/tree/master>
 
=head1 SEE ALSO
 
L<Net::GitHub>
 
=cut

my $dispatch = {
    'exit'  => sub { exit; },
    'quit'  => sub { exit; },
    'q'     => sub { exit; },
    '?'     => \&help,
    'h'     => \&help,

    # Common
    repo    => \&set_repo,
    login   => \&set_login,
    loadcfg => \&set_loadcfg,
    
    # Repo
    'r.show'    => sub { shift->run_basic_repo_cmd( 'repos', 'get', shift ); },
    'r.list'    => \&repo_list,
    'r.watch'    => sub { shift->run_basic_repo_cmd( 'repos', 'watch', shift ); },
    'r.unwatch'  => sub { shift->run_basic_repo_cmd( 'repos', 'unwatch', shift ); },
    'r.fork'     => sub { shift->run_basic_repo_cmd( 'repos', 'create_fork', shift ); },
    'r.create'   => \&repo_create,
    'r.set_private' => sub { shift->repo_update( private => \1, shift ); },
    'r.set_public'  => sub { shift->repo_update( private => \0, shift ); },
    # XXX? TODO, deploy_keys collaborators
    
    # Issues
    'i.list'    => sub {
        my ( $self, $type ) = @_;
        $type ||= 'open';
        $self->run_github_with_repo( 'issue', 'repos_issues', { state => $type } );
    },
    'i.view'    => sub { shift->run_github_with_repo( 'issue', 'issue', shift ); },
    'i.open'    => sub { shift->issue_open_or_edit( 'open' ) },
    'i.edit'    => sub { shift->issue_open_or_edit( 'edit', @_ ) },
    'i.close'   => sub { shift->run_github( 'issue', 'close', shift ); },
    'i.reopen'  => sub { shift->run_github( 'issue', 'reopen', shift ); },
    'i.label'   => \&issue_label,
    'i.comment' => \&issue_comment,
    
    # User
    'u.show'   => sub { shift->run_github( 'user', 'show', shift ); },
    'u.update' => \&user_update,
    'u.followers' => sub { shift->run_github( 'user', 'followers' ); },
    'u.following' => sub { shift->run_github( 'user', 'following' ); },
    'u.follow'    => sub { shift->run_github( 'user', 'follow', shift ); },
    'u.unfollow'  => sub { shift->run_github( 'user', 'unfollow', shift ); },
    'u.pub_keys'  => sub { shift->user_pub_keys( 'show' ); },
    'u.pub_keys.add' => sub { shift->user_pub_keys( 'add', @_ ); },
    'u.pub_keys.del' => sub { shift->user_pub_keys( 'del', @_ ); },
    
    # Commits
    'c.branch'  => sub { shift->run_github( 'commit', 'branch', shift ); },
    'c.file'    => sub {
        my ( $self, $arg ) = @_;
        my @args = split(/\s+/, $arg, 2);
        @args = ('master', $args[0]) if scalar @args == 1;
        $self->run_github( 'commit', 'file', @args );
    },
    'c.show'    => sub { shift->run_github( 'commit', 'show', shift ); },
    
    # Object
    'o.tree'    => sub { shift->run_github( 'object', 'tree', shift ); },
    'o.blob'    => sub {
        my ( $self, $arg ) = @_;
        my @args = split(/\s+/, $arg, 2);
        $self->run_github( 'object', 'blob', @args );
    },
    'o.raw'     => sub { shift->run_github( 'object', 'raw',  shift ); },
};

sub run {
    my $self = shift;

    $self->print(<<START);
Welcome to GitHub Command Tools! (Ver: $VERSION)
Type '?' or 'h' for help.
START

    $self->set_loadcfg(1);
    while ( defined (my $command = $self->read) ) {

        $command =~ s/(^\s+|\s+$)//g;
        next unless length($command);

        # check dispatch
        if ( exists $dispatch->{$command} ) {
            $dispatch->{$command}->( $self );
        } else {
            # split the command out
            ( $command, my $args ) = split(/\s+/, $command, 2);
            if ( $command and exists $dispatch->{$command} ) {
                $dispatch->{$command}->( $self, $args );
            } else {
                $self->print("Unknown command, type '?' or 'h' for help");
                next unless $command;
            }
        }

        $self->term->addhistory($command) if $command =~ /\S/;
    }
}

sub help {
    my $self = shift;
    $self->print(<<HELP);
 command   argument          description
 repo      :user :repo       set owner/repo, eg: 'fayland perl-app-github'
 login     :login :token     authenticated as :login
 loadcfg                     authed by git config --global github.user|token
 ?,h                         help
 q,exit,quit                 exit

Repos
 r.show                      more in-depth information for the :repo
 r.list                      list out all the repositories for the :user
 r.watch                     watch repositories (auth required)
 r.unwatch                   unwatch repositories (auth required)
 r.fork                      fork a repository (auth required)
 r.create                    create a new repository (auth required)
 r.set_private               set a public repo private (auth required)
 r.set_public                set a private repo public (auth required)

Issues
 i.list    open|closed       see a list of issues for a project
 i.view    :number           get data on an individual issue by number
 i.open                      open a new issue (auth required)
 i.close   :number           close an issue (auth required)
 i.reopen  :number           reopen an issue (auth required)
 i.edit    :number           edit an issue (auth required)
 i.comment :number
 i.label   add|del :num :label
                             add/remove a label (auth required)

Users
 u.show                      get extended information on user
 u.update                    update your users info (auth required)
 u.followers
 u.following
 u.follow  :user             follow :user (auth required)
 u.unfollow :user            unfollow :user (auth required)
 u.pub_keys                  Public Key Management (auth required)
 u.pub_keys.add
 u.pub_keys.del :number

Commits
 c.branch  :branch           list commits for a branch
 c.file    :branch :file     get all the commits modified the file
 c.file    :file             (default branch 'master')
 c.show    :sha1             show a specific commit

Objects
 o.tree    :tree_sha1        get the contents of a tree by tree sha
 o.blob    :tree_sha1 :file  get the data of a blob by tree sha and path
 o.raw     :sha1             get the data of a blob (tree, file or commits)

Others
 r.show    :user :repo       more in-depth information for a repository
 r.list    :user             list out all the repositories for a user
 u.show    :user             get extended information on :user
HELP
}

sub set_repo {
    my ( $self, $repo ) = @_;
    
    # validate
    unless ( $repo =~ $self->repo_regexp ) {
        $self->print("Wrong repo args ($repo), eg 'fayland perl-app-github'");
        return;
    }
    my ( $owner, $name ) = ( $repo =~ $self->repo_regexp );
    $self->{_data}->{owner} = $owner;
    $self->{_data}->{repo} = $name;
    
    # when call 'login' before 'repo'
    my @logins = ( $self->{_data}->{login} and $self->{_data}->{token} ) ? (
        login => $self->{_data}->{login}, token => $self->{_data}->{token}
    ) : ();
    
    $self->{github} = Net::GitHub->new(
        owner => $owner, repo => $name,
        version => 3, pass => $self->{_data}->{token},
        @logins,
    );
    $self->{prompt} = "$owner/$name> ";
}

sub set_login {
    my ( $self, $login ) = @_;
    
    ( $login, my $token ) = split(/\s+/, $login, 2);
    unless ( $login and $token ) {
        $self->print("Wrong login args ($login $token), eg fayland 54b5197d7f92f52abc5c7149b313cf51");
        return;
    }

    $self->_do_login( $login, $token );
}

sub set_loadcfg {
    my ( $self, $ign ) = @_;
    
    my $login = `git config --global github.user`;
    my $token = `git config --global github.token`;
    chomp($login); chomp($token);
    unless ( ($login and $token) or $ign ) {
        $self->print("run git config --global github.user|token fails");
        return;
    }
    
    $self->_do_login( $login, $token ) if $login and $token;
}

sub _do_login {
    my ( $self, $login, $token ) = @_;
    
    # save for set_repo
    $self->{_data}->{login} = $login;
    $self->{_data}->{token} = $token;

    if ( $self->{_data}->{repo} ) {
        $self->{github} = Net::GitHub->new(
            version => 3,
            owner => $self->{_data}->{owner}, repo  => $self->{_data}->{repo},
            login => $self->{_data}->{login}, pass => $self->{_data}->{token}
        );
    } else {
        # Create a Net::GitHub object with the owner set to the logged in user
        # Super convenient if you don't want to set a user first
        $self->{github} = Net::GitHub->new(
            version => 3,
            login => $self->{_data}->{login}, pass => $self->{_data}->{token},
            owner => $self->{_data}->{login}
        );
    }
}

sub run_github {
    my ( $self, $c1, $c2 ) = @_;
    
    unless ( $self->github ) {
        $self->print(q~not enough information. try calling login :user :token or loadcfg~);
        return;
    }
    
    my @args = splice( @_, 3, scalar @_ - 3 );
    eval {
        my $result = $self->github->$c1->$c2(@args);
        # o.raw return plain text
        if ( ref $result ) {
            $result = JSON::XS->new->utf8->pretty->encode( $result );
        }
        $self->print( $result );
    };
    
    if ( $@ ) {
        # custom error
        if ( $@ =~ /login and token are required/ ) {
            $self->print(qq~authentication required.\ntry 'login :owner :token' or 'loadcfg' first\n~);
        } else {
            $self->print($@);
        }
    }
}

sub run_github_with_repo {
    my ( $self ) = shift;

    unless ( $self->{_data}->{repo} ) {
        $self->print(q~no repo specified. try calling repo :owner :repo~);
        return;
    }

    $self->run_github( shift, shift, $self->{_data}->{owner}, $self->{_data}->{repo}, @_ );
}

sub run_basic_repo_cmd {
    my ( $self, $obj, $meth, $args ) = @_;

    if ( $args and $args =~ $self->repo_regexp ) {
        $self->run_github( $obj, $meth, $1, $2 );
    } else {
        $self->run_github_with_repo( $obj, $meth );
    }
}

################## Repos
sub repo_list {
    my ( $self, $args ) = @_;
    if ( $args and $args =~ /^[\w\-]+$/ ) {
        $self->run_github( 'repos', 'list', $args );
    } else {
        $self->run_github( 'repos', 'list' );
    }
}

sub repo_create {
    my ( $self ) = @_;
    
    my %data;
    foreach my $col ( 'name', 'description', 'homepage' ) {
        my $data = $self->read( ucfirst($col) . ': ' );
        $data{$col} = $data;
    }
    unless ( length( $data{name} ) ) {
        $self->print('create repo failed. name is required');
        return;
    }
    
    $self->run_github( 'repos', 'create', \%data );
}

sub repo_update {
    my ( $self, $param, $value, $args ) = @_;

    if ( $args and $args =~ $self->repo_regexp ) {
        $self->run_github( 'repos', 'update', $1, $2, { $param => $value, name => $2 } );
    } else {
        unless ($self->{_data}->{repo}) {
            $self->print(q~no repo specified. try calling repo :owner :repo~);
            return;
        }

        $self->run_github_with_repo( 'repos', 'update', { $param => $value, name => $self->{_data}->{repo} } );
    }
}

# Issues
sub issue_open_or_edit {
    my ( $self, $type, $number ) = @_;
    
    if ( $type eq 'edit' and $number !~ /^\d+$/ ) {
        $self->print('unknown argument. i.edit :number');
        return;
    }
    
    my $title = $self->read( 'Title: ' );
    my $body  = $self->read( 'Body (use EOF to submit, use QUIT to cancel): ' );
    while ( my $data = $self->read( '> ' ) ) {
        last   if ( $data eq 'EOF');
        return if ( $data eq 'QUIT' );
        $body .= "\n" . $data;
    }
    
    if ( $type eq 'edit' ) {
        $self->run_github_with_repo( 'issue', 'update_issue', $number, { title => $title, body => $body } );
    } else {
        $self->run_github_with_repo( 'issue', 'create_issue', { title => $title, body => $body } );
    }
}

sub issue_label {
    my ( $self, $args ) = @_;
    
    no warnings 'uninitialized';
    my ( $type, $number, $label ) = split(/\s+/, $args, 3);
    if ( $type eq 'add' ) {
        $self->run_github_with_repo( 'issue', 'add_label', $number, $label );
    } elsif ( $type eq 'del' ) {
        $self->run_github_with_repo( 'issue', 'remove_label', $number, $label );
    } else {
        $self->print('unknown argument. i.label add|del :number :label');
    }
}

sub issue_comment {
    my ( $self, $number ) = @_;
    
    if ( $number !~ /^\d+$/ ) {
        $self->print('unknown argument. i.comment :number');
        return;
    }
    
    my $body = $self->read( 'Comment (use EOF to submit, use QUIT to cancel): ' );
    while ( my $data = $self->read( '> ' ) ) {
        last   if ( $data eq 'EOF');
        return if ( $data eq 'QUIT' );
        $body .= "\n" . $data;
    }
    
    $self->run_github_with_repo( 'issue', 'comment', $number, $body );
}

################## Users
sub user_update {
    my ( $self, $type ) = @_;
    
    # name, email, blog, company, location
    while ( ! ( $type and (grep { $_ eq $type } (qw/name email blog company location/)) ) ) {
        $type = $self->read( 'Update Key: (name, email, blog, company, location): ' );
    }
    my $value = $self->read( 'Value: ' );
    
    $self->run_github( 'user', 'update', $type, $value );
}

sub user_pub_keys {
    my ( $self, $type, $number ) = @_;
    
    if ( $type eq 'show' ) {
        $self->run_github( 'user', 'pub_keys' );
    } elsif ( $type eq 'add' ) {
        my $name = $self->read( 'Pub Key Name: ' );
        my $keyv = $self->read( 'Key: ' );
        $self->run_github( 'user', 'add_pub_key', $name, $keyv );
    } elsif ( $type eq 'del' ) {
        unless ( $number and $number =~ /^\d+$/ ) {
            $self->print('unknown argument. u.pub_keys.del :number');
            return;
        }
        $self->run_github( 'user', 'remove_pub_key', $number );
    }
}

1;
