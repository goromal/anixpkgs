# secure-delete

Secure file deletion utility, written in C.

[Repository](https://github.com/goromal/secure-delete)

```bash
secure-delete [-dflrvz] file1 file2 etc.

Options:
        -d  ignore the two dot special files "." and "..".
        -f  fast (and insecure mode): no /dev/urandom, no synchronize mode.
        -l  lessens the security (use twice for "totally insecure" mode).
        -r  recursive mode, deletes all subdirectories.
        -v  is verbose mode.
        -z  last wipe writes zeros instead of random data.

Does a secure overwrite/rename/delete of the target file(s).
Default is secure mode (38 writes).
```

The deletion process is as follows:

1. Overwrite the file with multiple passes. After each pass, the disk cache is flushed. The number of passes depends on the commanded mode:
  - (default / secure mode) 38 passes:
    - 1x overwrite with `0xff`.
    - 5x random passes.
    - 27x overwrites with [special values](https://www.cs.auckland.ac.nz/~pgut001/pubs/secure_del.html) to make the recovery from MFM- and RLL-encoded hard disks hard to impossible.
    - 5x random passes.
  - (insecure mode) 2 passes:
    - 1x overwrite with `0xff`.
    - 1x random pass.
  - (totally insecure mode) 1 pass:
    - 1x random pass.

2. Truncate the file, so that an observer wouldn't know which diskblocks belonged to the file.
3. Rename the file.
4. Delete (unlink) the file.

In 1 second you can approximately overwrite 1 to 2 MB of data (on a hard disk).

In "totally insecure" mode, in 15 seconds you can approximately overwrite 100 MB of data. The same deletion takes about 60 minutes in totally secure mode.

