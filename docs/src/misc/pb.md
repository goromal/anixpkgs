# pb

Print out a progress bar.

```
usage: pb [options] iternum itertot

Prints a progress bar.

Options:
-h | --help     Print out the help documentation.
-b | --barsize  Dictate the total progress bar length in chars (Default: 20).
-c | --color    One of [black|red|green|yellow|blue|magenta|cyan|white].

Arguments:
iternum: current iteration number
itertot: number of total iterations
```

Example usage:

```
Example Usage:
N=0
T=20
while [ $N -le $T ]; do
    pb $N $T
    N=$[$N+1]
    sleep 1
done
echo
```

