#!/bin/bash
set -Ceuo pipefail
set -x
rm -f ztest.tar ztest?.log
tar cvf ztest.tar LICENSE README.md test-r.sh test.sh
tar tvf ztest.tar > ztest1.log
ruby lib/tarreader.rb ztest.tar > ztest2.log
diff ztest1.log ztest2.log
