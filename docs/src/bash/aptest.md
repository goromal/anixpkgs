# aptest

Run a SITL instance of ardupilot from source.

## Sample Commands (for heli)

- If you're running LUA scripts and have some in an `ardupilot/scripts` directory:
  - `param set SCR_ENABLE 1`
  - `reboot`
- `param set DISARM_DELAY 0`
- `mode guided`
- `arm throttle`
- `takeoff 25`

## Usage (Auto-Generated)

```bash
usage: aptest [options] path_to_ardupilot

Run a SITL instance of ardupilot from source.

Options:
  -f|--frame     Copter frame to simulate [default: heli]


```

