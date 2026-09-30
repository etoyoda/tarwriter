#!/bin/bash
set -xeEuo pipefail

z100=$(ruby -e 'puts "z" * 100')
zy99=$(ruby -e 'puts("z" +("y" * 99))')

del() {
  for name in "$@"
  do
    test ! -f "${name}" || rm -f "${name}"
  done
}

del $z100 ztest30.tar
ln README.md $z100
ruby lib/tarwriter.rb ztest30.tar $z100
test $z100 = $(tar tf ztest30.tar )

del z$z100 ztest31.tar
ln $z100 z$z100
test ! -f ztest31.tar || rm -f ztest31.tar
! ruby lib/tarwriter.rb ztest31.tar z$z100
: above command is expected to fail

test ! -d $zy99 || rm -rf $zy99
mkdir $zy99
del $zy99/$z100 ztest32.tar
ln README.md $zy99/$z100
ruby lib/tarwriter.rb ztest32.tar $zy99/$z100
test $zy99/$z100 = $(tar tf ztest32.tar )

set -- $(ruby lib/tarreader.rb ztest32.tar)
test x$zy99/$z100 = x$6

echo all okay
