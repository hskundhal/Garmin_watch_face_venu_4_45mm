# Data Face – Garmin Venu 4 watch face

Digital watch face with: time (centre), date + day, battery %, weather + UV,
heart rate, body battery, stress, steps, sleep score, recovery hours, training readiness.

## Build / run (VS Code + Monkey C extension)
1. Open this folder in VS Code.
2. `Cmd+Shift+P` → **Monkey C: Verify Installation** (set your developer key if asked).
3. `Cmd+Shift+P` → **Monkey C: Build Current Project** / **Run** and pick the Venu 4 simulator.
4. To sideload: **Monkey C: Build for Device** → copy the `.prg` to the watch's `GARMIN/APPS` folder over USB.

## If the build fails on the device ID
`manifest.xml` targets `venu4`. Open the SDK Manager → Devices (or run
**Monkey C: Edit Products**) and tick the Venu 4 entry. If your SDK lists a
different ID (e.g. a 41mm variant), add it as another `<iq:product id="..."/>`.

## Sleep score / training readiness / recovery
These are matched by label through the Complications API. Open the console
while running: lines starting with `[complication]` show what your watch exposes.
Anything not found shows `--`. If Garmin names them differently on your firmware,
adjust the `label.find(...)` checks in `findComplications()` in `source/DataFaceView.mc`.
The simulator usually has no real values for these; check on the watch.
