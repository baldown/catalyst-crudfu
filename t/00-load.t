#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Catalyst::Controller::DBIC::CRUDFu' ) || print "Bail out!\n";
}

diag( "Testing Catalyst::Controller::DBIC::CRUDFu $Catalyst::Controller::DBIC::CRUDFu::VERSION, Perl $], $^X" );
