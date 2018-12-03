set -x
set -e
test ! -f ztest1.tar || rm -f ztest1.tar
ruby lib/tarwriter.rb ztest1.tar tarwriter.gemspec test.sh
tar tvf ztest1.tar
tar -cvf ztest2.tar --format ustar --owner nobody --group nobody tarwriter.gemspec test.sh
tar tvf ztest2.tar
od -Ad -w10 -c ztest1.tar > ztest1.txt
od -Ad -w10 -c ztest2.tar > ztest2.txt
diff -c ztest2.txt ztest1.txt > zdiff.txt
