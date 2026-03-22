# fix-perms

Recursively claim ownership of all files and folders in dir.


## Usage

```bash
usage: fix-perms dir

Recursively claim ownership of all files and folders in dir. Attempts to deduce special cases such as ~/.ssh/*.

EXAMPLES:

Current directory is ~/.ssh:

  find . -type d -exec chmod 700 {} \;
  find . -type f -exec chmod 600 {} \;
  find . -type f -name \*.pub -exec chmod 644 {} \;

Current directory is a normal directory:

  find . -type d -exec chmod 755 {} \;
  find . -type f -exec chmod 644 {} \;

```

