package App::GitHub::Test;

use strict;
use warnings;

use v5.10;

use Test::MockObject;
use Exporter 'import';
our @EXPORT_OK = ( qw/init_app_github setup_pipe/ );

use lib "../../../../lib";

use App::GitHub;

sub init_app_github {
	my $mock_ngh = Test::MockObject->new;
	$mock_ngh->set_isa( "Net::GitHub" );

	return App::GitHub->new( github => $mock_ngh );
}

1;