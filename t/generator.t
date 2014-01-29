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

package MyTest;
use base 'Plasticine::Object';

our $var1 :Get;
our $var2 :Get = 15;
our $var3 :Get Default([1..5]);
our $var4 :Get Set Default(sub { return 5 * 8 } );
our $var5 :Get Set(sub { my $self = shift; $self->_data->{var5} = shift() * 5; }) = 5;

sub test1 :Private {
    return 'private sub';
}

sub test2 {
    return shift->test1;
}

sub test3 :Protected {
    return 'protected sub';
}

package SubTest;
use base 'MyTest';

sub test4 {
    return shift->test3;
}

package AnotherTest;
use base 'Plasticine::Generator';

sub new { return bless {}, shift };

our $var1 :Get Set = 35;

package main;
use Test::More;
use Data::Dumper;

$SIG{__DIE__} = sub {
    my $err = shift;
    if (ref $err eq 'Plasticine::Exception') {
        warn $err;
    }
};

sub throw_ok(&@) {
    my ($sub, $code, $msg) = @_;
    eval {
        $sub->();
    };
    $msg //= "throws $code";
    if (my $err = $@) {
        if (ref $err eq 'Plasticine::Exception') {
            is($err->code, $code, $msg);
        } else {
            isa_ok($err, 'Plasticine::Exception', $msg);
        }
        return;
    }
    ok(0, $msg);
}

use_ok('Plasticine::Generator');

my $obj = new_ok('MyTest');

ok(!$obj->var1, 'getter undef');
throw_ok { $obj->var1(123) } 'ERROR_NOT_IMPLEMENTED';

is($obj->var2, 15);
is_deeply($obj->var3, [ 1..5 ], 'default value - arrayref');
is($obj->var4, 40, 'default value - sub');
is($obj->var4(10), 10, 'setter');
is($obj->var4, 10, 'check setter');
is($obj->var5, 5);
is($obj->var5(3), 15);
is($obj->var5, 15);

throw_ok { $obj->test1; } 'ERROR_INVALID_ACCESS';
is($obj->test2, 'private sub');
throw_ok { $obj->test3; } 'ERROR_INVALID_ACCESS';

my $obj1 = new_ok('SubTest');

is($obj1->test4, 'protected sub');

my $obj2 = new_ok('AnotherTest');
is($obj2->var1, 35);
is($obj2->var1(10), 10);
is($obj2->var1, 10);

done_testing();

