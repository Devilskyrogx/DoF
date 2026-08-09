# DoF/Tools/insert_keys.pl
#
# Вставляет готовый блок ключей локали перед закрывающей "})" файла.
# Нужен, потому что вставлять многострочные UTF-8 блоки однострочными
# командами оболочки — верный способ поймать проблемы с кавычками.
#
#   perl Tools/insert_keys.pl <файл_локали> <файл_с_блоком>

use strict;
use warnings;

my ($file, $block) = @ARGV;
die "usage: insert_keys.pl <locale_file> <block_file>\n" unless $file && $block;

open my $f, '<:encoding(UTF-8)', $file  or die "cannot read $file: $!";
my @lines = <$f>;
close $f;

open my $b, '<:encoding(UTF-8)', $block or die "cannot read $block: $!";
my @insert = <$b>;
close $b;

# Ищем закрывающую скобку таблицы с конца — вложенных "})" в локали не бывает,
# но так надёжнее, если файл когда-нибудь обрастёт хвостом.
my $at;
for my $n (reverse 0 .. $#lines) {
    if ($lines[$n] =~ /^\}\)/) { $at = $n; last; }
}
die "no closing '})' found in $file\n" unless defined $at;

splice(@lines, $at, 0, @insert);

open my $o, '>:encoding(UTF-8)', $file or die "cannot write $file: $!";
print $o @lines;
close $o;

printf "%s: вставлено строк %d\n", $file, scalar(@insert);
