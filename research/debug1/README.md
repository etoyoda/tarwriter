# debug - sometimes "tar tvf" aborts with "A lone zero block" message

The tarwriter version 1.1.0 and before makes a tar archive that causes error with tar(1).
An extra zero block (512 octet size) is added just after the file with size multiple of 512.

That was caused by misunderstanding of behavior of String#byteslice.

## tardump.rb

Dumps header block, skips data blocks, and iterates until the end of file.

## blkbound.rb

The code reproduces the error.  The script produces two tar archives,
"bstd.tar" by system tar(1) utility, and "blib.tar" by tarwriter library.
The two tar archives are supposed to have same structure, and that can be tested by tardump.rb.

## test-byteslice.rb

Test code of String#byteslice behavior.  "String ... of 1024 bytes".byteslice(1024, 512) returns
empty string.  The bug was caused by misunderstanding that byteslice returned nil in such case.
