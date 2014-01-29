use utf8;
use 5.10.0;
use strict;
use warnings;
no warnings 'uninitialized';

package Plasticine::Exception;

=head1 NAME

Plasticine::Exception - модуль для генерации исключений

=head1 SYNOPSIS

    sub test {
        ...
        unless ($state_ok) {
            throw ERR_CUSTOM_ERROR => 'Error description';
        }
    }

    ...
    eval {
        $ENV{TRACE} = 1; # включаем принудительную трассировку стэка
        test();
    };

    if (my $err = $@) {
        warn $err; # выводим полную информацию об ошибке
        my $code = $err->code; # код ошибки
        my $message = $err->message; # сообщение об ошибке
        my $stack = $err->stack; # трассировка стэка
    }

=head1 DESCRIPTION

Генерация исключений с опциональной трассировкой стэка "на борту". Можно
использовать явно как класс или через экспортируемую функцию throw.

=cut

use Carp;
our @ISA = qw(Exporter);
our @EXPORT = qw(throw);
require Exporter;

# Чтобы данный пакет не светился в трассировке стэка
$Carp::Internal{ (__PACKAGE__) }++;

# Чтобы пойманная ошибка автоматически транслировалась в строку при выводе
use overload '""' => sub {
    return shift->as_string;
};

=head1 METHODS

=head2 new

Конструктор класса. Аргументы:

=over 1

=item $code

Код ошибки

=item $message

Детальное описание ошибки

=item $trace

Выполнять ли трассировку стэка. По умолчанию - не выполнять. Если установлена
переменная окружения TRACE = 1, то трассировка по умолчанию выполняется, но
ее можно отключить, передав в качестве значения параметра $trace 0.

=back

    throw ERR_CODE => 'Error message'; # без трассировки стэка
    throw ERR_CODE => 'Error message', 1; # явно задана трассировка стэка
    $ENV{TRACE} = 1; # включаем трассировку по умолчанию
    throw ERR_CODE => 'Error message'; # с трассировкой стэка
    throw ERR_CODE => 'Error message', 0; # выключаем трассировку стэка

    # можно позвать конструктор явно
    die Plasticine::Exception->new(ERR_CODE => 'Error message');

=cut
sub new {
    my $class = shift;
    my ($code, $message, $trace) = @_;
    $trace = 1 if $ENV{TRACE} && !defined $trace;
    my $self = bless { code => $code, message => $message, trace => $trace}, $class;
    return $self unless $self->{trace};
    my $stack = Carp::longmess;
    # Почистим вывод от лишних данных, если запускаемся в контексте Mojolicious
    $stack =~ s/Mojo.+//gms;
    $self->{stack} = $stack;
    return $self;
}

=head2 code

Код ошибки

=cut
sub code {
    return shift->{code};
}

=head2 message

Детальное описание ошибки

=cut
sub message {
    return shift->{message};
}

=head2 trace

Флаг трассировки стэка

=cut
sub trace {
    return shift->{trace};
}

=head2 stack

Трассировка стэка

=cut
sub stack {
    return shift->{stack};
}

=head2 as_string

Экспортирует данные исключения в строку

=cut
sub as_string {
    my $self = shift;
    return $self->code . ': ' . $self->message . ($self->trace ? "\n" . $self->stack : '');
}

=head1 EXPORT

=head2 throw

Создает экземпляр исключения с переданными параметрами и вызывает die

    throw ERR_TEST => 'Error message';

=cut
sub throw(@) {
    my ($code, $message, $trace) = @_;
    die __PACKAGE__->new($code, $message, $trace);
}

=head1 AUTHOR

Elena Shishkina <miralita@gmail.com>

=cut

1;
