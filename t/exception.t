use 5.12.0;
use utf8;
use strict;
use warnings;

our $path;

BEGIN {
    use Cwd 'abs_path';
    $path = abs_path(__FILE__);
    ($path) = $path =~ m|^(.+/)t/?|;
}

use lib $path . 'lib';
use Test::More;
use Plasticine::Exception;

$ENV{TRACE} = 1;
eval {
    throw ERR_TEST => 'Test error';
};


my $err = $@;
is($err->code, 'ERR_TEST');
is($err->message, 'Test error');
ok($err->stack);

done_testing();

