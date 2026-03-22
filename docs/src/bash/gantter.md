# gantter

Generate Gantt charts from text files.


## Usage

```bash
usage: gantter specfile

Create a Gantt-based dependency chart for tasks, laid out by the specfile.
Example specfile contents:
--------------------------------------------------------------------------
1>> Coverage Planner
1.1>> Learn interface for outer loop
1.2>> [[1.1]] ((2)) Connect Lab 4 code with outer loop
1.3>> [[2.1]] [[3.1]] ((3)) Waiting for SLAM

2>> SLAM Algorithm
2.1>> Something

3>> System-Level Evaluation
3.1>> Another thing
--------------------------------------------------------------------------
Double brackets [[]] indicate dependencies and double parentheses (()) 
indicate estimated time units required (assumes 1 if none given).

REQUIRES pdflatex to be in your system path (not interested in shipping 
texlive-full in its entirety with this little tool).

```

