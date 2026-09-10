# md2pdf

Convert Markdown files into formatted PDF files, powered by LaTeX.


## Usage

```bash
usage: md2pdf input.md output.pdf

Use LaTeX to convert a markdown file into a formatted pdf.

Vacuum sweeps files already in .pdf form only when an option
above (other than verbosity) asks for a different conversion; those are
re-encoded in place. Otherwise they are skipped as a no-op.

Vacuum options (vacuum requires orchestrator on PATH):
         --orch-port PORT        Orchestrator daemon port
         --orch-priority INT     Priority for dispatched jobs

```

