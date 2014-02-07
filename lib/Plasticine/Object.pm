use 5.10.0;
use utf8;
use strict;
use warnings;
package Plasticine::Object;

=head1 NAME

Plasticine::Object - базовый класс для создания объектов, скрывающих данные
от прямого доступа извне

=head1 SYNOPSIS

    package MyTest;

    sub new {
        my $class = shift;
        my $self = $class->SUPER::new(@_);
        ...
        return $self;
    }

=cut

# подключаем генератор как базовый класс, чтобы получить доступ к обработчикам
# атрибутов
use parent 'Plasticine::Attribute';

# хранилище для данных объектов
my $_Obj_Data = {};

=head1 PUBLIC METHODS

=head2 new

Базовый конструктор. В качестве аргумента принимает хэш с произвольным набором
ключей и значений, который сохраняет в данных объекта.

Если дочерний класс переопределяет конструктор, то вызов родительского
конструктора обязателен!

=cut
sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $_Obj_Data->{$self} = { @_ };
    return $self;
}

=head1 PROTECTED METHODS

=head2 _data

Прямой доступ к данным объекта

=cut
sub _data :Protected {
    return $_Obj_Data->{+shift};
}

# посмертная чистка данных объекта
sub DESTROY {
    delete $_Obj_Data->{+shift};
}

=head1 AUTHOR

Elena Shishkina <miralita@gmail.com>

=cut

1;
