#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Parallel::Forking::Manager' );
}

diag( "Testing Parallel::Forking::Manager $Parallel::Forking::Manager::VERSION, Perl $], $^X" );
