# code2pdf

Generate pretty-printed PDF files from source code files.


## Usage

```bash
usage: code2pdf infile output.pdf

Convert plain text code infile to color-coded pdf outfile.

Recursive search example for C++ files:
for f in $(find . -name '*.cpp' -or -name '*.h'); do code2pdf $f $f.pdf; done

Vacuum sweeps files already in .pdf form only when an option
above (other than verbosity) asks for a different conversion; those are
re-encoded in place. Otherwise they are skipped as a no-op.

Vacuum options (vacuum requires orchestrator on PATH):
         --orch-port PORT        Orchestrator daemon port
         --orch-priority INT     Priority for dispatched jobs

```

