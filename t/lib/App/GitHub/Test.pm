package App::GitHub::Test;

use strict;
use warnings;

use v5.10;

use Test::MockObject;
use Exporter 'import';
our @EXPORT_OK = ( qw/init_app_github/ );

use App::GitHub;

sub init_app_github {         
    if ( not exists $ENV{COLUMNS} ) {
        $ENV{COLUMNS} = 80;
        $ENV{LINES}   = 3;
    }
    
    my $mock_ngh = Test::MockObject->new;
    $mock_ngh->set_isa( "Net::GitHub" );
    
    my $mock_readline = Test::MockObject->new;
    $mock_readline->set_isa( "Term::ReadLine" );
    $mock_readline->mock( ReadLine => sub { "Mock " });
    $mock_readline->mock( readline => sub {
        my $line = <STDIN>;
        chomp $line;
        return $line;
    });

    return App::GitHub->new( github => $mock_ngh, 
                             out_fh => \*STDOUT,
                             term => $mock_readline );
}

1;