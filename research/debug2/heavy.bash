#!/bin/bash
set -Ceuo pipefail
PATH=/bin:/usr/local/bin:/usr/bin
LANG=C

script=../../lib/tarwriter.rb

wget -N http://www.data.jma.go.jp/developer/xml/feed/regular_l.xml

sed -n '/<link type="app/{s/.*href="//; s/".*//; p}' regular_l.xml > z.lst
head -100 z.lst | while read url
do
  base=`basename ${url}`
  wget -q -O${base} ${url}
  ruby -w $script -a z.tar ${base}
  rm -f ${base}
done
