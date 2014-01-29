use 5.14.0;
use utf8;
use strict;
use warnings;
package Plasticine::Attribute;

=head1 NAME

Plasticine::Attribute - генераторы кода

=head1 SYNOPSIS

    package MyTest;
    use base 'Plasticine::Attribute';

    sub new { return bless {}, shift };

    # ридонли аксессор
    our $var1 :Get;
    # ридонли аксессор с коллбэком в качестве значения
    our $var2 :Get(sub { return 123 });
    # ридонли аксессор с дефолтным значением из значения переменной
    our $var3 :Get = 55;
    # сеттер. Если не указать геттер, то всегда будет возвращать undef
    our $var4 :Get Set;
    # сеттер с дефолтным значением, заданным коллбэком
    our $var5 :Get Set Default(sub { return 123; });
    # сеттер с кастомным коллбэком и дефолтным значением из значения переменной
    our $var6 :Get Set(sub { my $self = shift; $self->{var6} = shift() * 5; }) = 5;

=head1 DESCRIPTION

Модуль генерирует аксессоры для классов, а также модификаторы доступа.
Корректно работает как с обычного классами, так и с наследниками
Plasticine::Object

Генераторы умеют устанавливать в качестве аксессоров произвольные коллбэки, но
в этом случае забота о правильном доступе к данным объекта ложится на
вызывающую сторону.

Генераторы не сработают, если в пакете есть методы с именами, как у переменных,
для которых задана генерация аксессоров: существующие методы не переопределяются

=cut

# модуль для установки кастомных обработчиков атрибутов
use Attribute::Handlers;
# понадобится для переименования анонимных функций
use Sub::Name;
# структуры при отдаче наружу будем клонировать
use Storable qw(dclone);

use Plasticine::Exception;

# выключаем лишнюю ругань в логах
no warnings 'redefine';
no warnings 'uninitialized';
no strict 'refs';

=head1 ATTRIBUTE HANDLERS

=head2 Get

Генерирует геттер на основе пакетной переменной. В качестве геттера также
можно указать свой коллбэк.

    our $var :Get;
    # с кастомным коллбэком
    our $var :Get(sub { return 123 });
    # для обычного класса
    our $var :Get(sub { return shift->{var} });
    # для наследника Plasticine::Object
    our $var :Get(sub { return shift->_data->{var} });
    # значение по умолчанию из значения пакетной переменной
    our $var :Get = 15;

Работает ТОЛЬКО со скалярами!

=cut
sub Get :ATTR(SCALAR) {
    my ($package, $symbol, undef, undef, $data) = @_;
    # Генерируем основной метод
    __make_accessor_stub($symbol);
    # Имя, под которым наш геттер будет сохранен в таблице символов
    my $name = $package . '::__get_' . *{$symbol}{NAME};
    # Имя пакетной переменной, на основе которой генерируется аксессор
    my $var = *{$symbol}{NAME};
    # Если в параметрах атрибута нам передали коллбэк, то его и используем.
    # Любые другие параметры атрибута просто игнорируются
    my $sub = (ref $data eq 'ARRAY' && @$data && ref $data->[0] && ref $data->[0] eq 'CODE')
        ? $data->[0]
        : sub {
        my $self = shift;
        # Если класс является наследником Plasticine::Object, то для доступа
        # к данным объекта надо позвать метод _data, если обычный класс -
        # то берем $self
        my $data = $self->isa('Plasticine::Object') ? $self->_data : $self;
        # Берем значение параметра, при необходимости инициализируем дефолтным
        # значением
        my $value = exists $data->{$var} ? $data->{$var} : $data->{$var} //= $package->can('__default_' . $var)->($self);

        if (ref $value && (ref $value eq 'ARRAY' || ref $value eq 'HASH')) {
            # структуры клонируем
            return dclone $value;
        } else {
            # все остальное возвращаем as is
            return $value;
        }
    };
    # Воспользуемся subname для присваивания имени анонимной функции,
    # сохраним функцию в таблице символов пакета
    *{$name} = subname $name => $sub;
}

=head2 Set

Генерирует сеттер на основе пакетной переменной. В качестве сеттера также
можно указать коллбэк.

    our $var :Get Set;
    our $var :Get Set = 15;
    # для обычного класса
    our $var :Get Set(sub { my $self = shift; $self->{var} = shift; });
    # для наследника Plasticine::Object
    our $var :Get Set(sub { my $self = shift; $self->_data->{var} = shift; });

=cut
sub Set :ATTR(SCALAR) {
    my ($package, $symbol, undef, undef, $data) = @_;
    # Генерируем основной метод
    __make_accessor_stub($symbol);
    # Определяем имя, под которым метод будет сохранен в таблице символов пакета
    my $name = $package . '::__set_' . *{$symbol}{NAME};
    # Берем имя параметра из имени пакетной переменной
    my $var = *{$symbol}{NAME};
    # Если в параметрах атрибута нам передали коллбэк, то используем его.
    # Другие параметры игнорируем
    my $sub = (ref $data eq 'ARRAY' && @$data && ref $data->[0] && ref $data->[0] eq 'CODE')
        ? $data->[0]
        : sub {
        my $self = shift;
        # Для наследником Plasticine::Object берем данные объекта из метода
        # _data, для обычных классов - из $self
        my $data = $self->isa('Plasticine::Object') ? $self->_data : $self;
        $data->{$var} = shift;
        # Зовем геттер, чтобы вернуть значение (геттер сделает клонирование
        # при необходимости)
        return $self->$var();
    };
    # Воспользуемся subname для присваивания имени анонимной функции,
    # сохраним функцию в таблице символов пакета
    *{$name} = subname $name => $sub;
}

=head2 Default

Генерирует метод, возвращающий дефолтное значение параметра. Дефолтным
значением может быть коллбэк или скаляр. Данный обработчик атрибута
переопределяет стандартную заглушку, которая берет дефолтное значение из
пакетной переменной, на основе которой генерируется аксессор.

Обработчик атрибута берет только первый из переданных ему параметров. Остальные
отбрасываются.

    # дефолтное значение из пакетной переменной
    our $var :Get Set = 15;
    # дефолтное значение устанавливается явно
    our $var :Get Set Default(15);
    # дефолтное значение - ленивая инициализация, коллбэк
    our $var :Get Set Default(sub {
        my $self = shift;
        my $data = $self->_data;
        return [ split /,/, $data->{another_var} ];
    });

=cut
sub Default :ATTR(SCALAR) {
    my ($package, $symbol, undef, undef, $data) = @_;
    # Генерируем основной метод
    __make_accessor_stub($symbol);
    # Определяем имя, под которым метод будет сохранен в таблице символов пакета
    my $name = $package . '::__default_' . *{$symbol}{NAME};
    # Берем имя параметра из имени пакетной переменной
    my $var = *{$symbol}{NAME};
    $data //= [];
    # Если в параметрах атрибута нам передали коллбэк, то используем его.
    # Если что-то другое - то генерируем функцию, которая возвращает первый
    # из переданных обработчику атрибута параметров
    my $sub = (@$data && ref $data->[0] && ref $data->[0] eq 'CODE')
        ? $data->[0]
        : sub {
        my $self = shift;
        return $data->[0];
    };
    # Воспользуемся subname для присваивания имени анонимной функции,
    # сохраним функцию в таблице символов пакета
    *{$name} = subname $name => $sub;
}

=head2 Private

Делает метод приватным (т.е. доступным только из текущего пакета)

    sub method :Private {
        ...
    }

=cut
sub Private :ATTR(CODE) {
    my ($package, $symbol, $sub, undef, $data) = @_;
    my $name = *{$symbol}{NAME};
    *{$symbol} = subname "$package\::$name" => sub {
        my $caller = caller;
        # Немного магии, чтобы обойти проблему с генераторами и манипуляцией
        # с таблицей символов. Первый элемент caller всегда возвращает настоящее
        # имя вызывающего пакета, а четвертый элемент поддается манипуляции
        # через subname.
        # Причем первый элемент относится к вызывающему пакету, а третий -
        # к текущей функции, т.е., чтобы использовать для определения вызывающего
        # пакета третий элемент вместо первого, нам надо спуститься по стэку
        # на фрейм ниже
        if ($caller eq __PACKAGE__) {
            # мы внутри генератора, поэтому для получения подделанного через
            # subname имени метода спускаемся на фрейм ниже
            $caller = (caller(1))[3];
            # отрезаем имя функции - нам нужен только пакет
            $caller =~ s/::[^:]+$//;
        }
        # кидаем исключение, если нас позвали не из пакета, запросившего
        # обработчик атрибута
        throw ERROR_INVALID_ACCESS => "Can't call private sub $package\::$name from $caller" if $caller ne $package;
        # подрезаем стэк и прыгаем сразу на вызов оригинального метода
        goto &$sub;
    };
}

=head2 Protected

Делает метод защищенным (т.е. доступным только из текущего пакета и его
наследников)

    sub method :Protected {
        ...
    }

=cut
sub Protected :ATTR(CODE) {
    my ($package, $symbol, $sub, undef, $data) = @_;
    my $name = *{$symbol}{NAME};
    *{$symbol} = subname "$package\::$name" => sub {
        # про магию см. камент к Private
        my $caller = caller;
        if ($caller eq __PACKAGE__) {
            $caller = (caller(1))[3];
            $caller =~ s/::[^:]+$//;
        }
        # кидаем исключение, если нас позвали не из пакета, запросившего
        # обработчик атрибута, или его наследника
        throw ERROR_INVALID_ACCESS => "Can't call protected sub $package\::$name from $caller" unless $caller->isa($package);
        # подрезаем стэк и прыгаем сразу на вызов оригинального метода
        goto &$sub;
    };
}

# Генератор основного метода
sub __make_accessor_stub {
    my $symbol = shift;
    # Выполняем работу, только если в таблице символов еще ничего не сгенерировано
    unless (*{$symbol}{CODE}) {
        # Берем имя пакета из глоба
        my $package = *{$symbol}{PACKAGE};
        # И имя переменной
        my $name = *{$symbol}{NAME};
        my $fullname = *{$symbol}{PACKAGE} . '::' . *{$symbol}{NAME};
        # Генерируем геттер по умолчанию, который возвращает пустоту.
        # Если вызывающая сторона задает атрибут Get, то геттер будет
        # переопределен
        *{$package . '::__get_' . $name} = subname $package . '::__get_' . $name => sub {
            return;
        };
        # Генерируем сеттер по умолчанию, который кидает исключение.
        # Если вызывающая сторона задает атрибут Set, то сеттер будет
        # переопределен
        *{$package . '::__set_' . $name} = subname $package . '::__set_' . $name => sub {
            my $ref = (caller(1))[3];
            throw ERROR_NOT_IMPLEMENTED => "Setter for $package\::$name isn't defined";
        };
        # Генерируем функцию, возвращающую дефолтное значение поля
        # (по умолчанию берется из пакетной переменной). Если вызывающая сторона
        # задает атрибут Default, то этот метод будет переопределен
        *{$package . '::__default_' . $name} = subname $package . '::__default_' . $name => sub {
            return ${ *{$symbol}{SCALAR} };
        };

        # Генерируем основной метод
        *{$symbol} = subname $fullname => sub {
            my $self = shift;
            # Немножко оптимизации - сохраняем геттер и сеттер в статических
            # переменных. Реально этот код отработает не сейчас, а при первом
            # обращении к аксессору, т.е. когда все обработчики атрибутов
            # уже сгенерируют все необходимые функции
            state $getter = $package->can('__get_' . $name);
            state $setter = $package->can('__set_' . $name);
            if (@_) {
                # Если у нас что-то пришло в параметрах вызова, кроме объекта,
                # даже undef, то зовем сеттер
                return $setter->($self, @_);
            } else {
                # если ничего не передали, то зовем геттер
                return $getter->($self);
            }
        };
    }
}

=head1 AUTHOR

Elena Shishkina <miralita@gmail.com>

=cut

1;
