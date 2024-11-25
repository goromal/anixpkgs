# code2pdf

Generate pretty-printed PDF files from source code files.


## Usage (Auto-Generated)

```bash
usage: code2pdf infile output.pdf

Convert plain text code infile to color-coded pdf outfile.

Recursive search example for C++ files:
for f in $(find . -name '*.cpp' -or -name '*.h'); do code2pdf $f $f.pdf; done


```

