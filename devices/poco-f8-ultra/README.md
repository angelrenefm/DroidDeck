# POCO F8 Ultra (Snapdragon 8 Elite Gen 5 / SM8850)

Notes from running DroidDeck on a POCO F8 Ultra: 12 GB RAM, Adreno 840, 120 Hz panel, HyperOS 3 (Android 16), no root. Everything here was measured on that phone, mostly with Hades. Frame numbers come from SurfaceFlinger (`droiddeckctl pacing`, #843), not from the game's own counter. That counter counts the frames a game hands over, not the ones that reach the screen.

## Settings that work (Hades)

| Build | Settings | fps on screen | intervals off-cadence |
|---|---|---|---|
| Preview `ec53742` (with #717) | 1564×720, limit 60, GSR on (`upscaler` 8, sharpness 100) | 59.0–59.8 | 0.0–1.3 % |
| Preview `ec53742` | 1564×720, limit 60, GSR off | 58.8 / 59.6 | 1.8 / 0.5 % |
| Stable 0.4.0 (before #717) | 1564×720, limit 60, GSR off | 55.6 / 57.5 | 7.7 / 4.2 % |

- **Resolution:** set the game itself to 1564×720 (the panel's shape). Hades then keeps its proportions and fills the sides with its own border art.
- **GSR** costs nothing visible on the Preview build. Before the #717 fix it caused stutter (49 fps on screen, 22 % off-cadence).

## Heat

This phone heats up fast under a game. The battery went from 31 to 44 °C in about 7 minutes with a 60 fps limit. Around 50 °C, HyperOS drops the panel to 60 Hz and frame rates fall to 43–70, whatever the settings. So:
- Compare settings only when the battery is below about 42 °C, and alternate A/B/B/A. Otherwise the heat decides the result.
- Don't cool it in a freezer: condensation inside the phone is a real risk.

## CPU cores

The SM8850 has 6 cores at 3.63 GHz (0–5) and 2 at 4.61 GHz (6–7). DroidDeck can pin the Steam client and the game to separate cores (`clientCpusOverride`, `clientCpus`, `gameCpus` in the session prefs, as comma-separated lists; a range like `0-5` is ignored).

Pinning the game to the two fast cores does not help. Hades, no fps limit, 120 Hz, 30 s captures, alternating A-B-B-A, each run starting with the battery below 38 °C:

| | fps on screen | off-cadence |
|---|---|---|
| A: all cores (default) | 119.8, 119.2 … 116.8, 116.3 (mean 118.0) | 0.1–3.1 % (mean 1.6 %) |
| B: game on 6–7, client on 0–5 | 113.8, 114.2, 112.0, 116.7 (mean 114.2) | 2.1–3.7 % (mean 3.0 %) |

With B, cores 6–7 sit at 66–70 % and the rest mostly idle; with A, the load is spread at 26–62 %. Across other evenings the same settings varied by ±3 fps, so the honest reading is "no gain, maybe slightly worse". Leave the defaults.

## Known issues on this phone

- **x86 Linux games ("Linux x86 (FEX)")** don't start yet: #839, #841 and the #579 thread. Games that also have a Windows version run fine through Proton.
- `droiddeckctl` needs `DROIDDECK_PACKAGE` for the antutu/ludashi builds (#842).

## Measuring

```bash
export DROIDDECK_PACKAGE=com.antutu.benchmark.full   # the build you have installed
tools/droiddeckctl pacing --seconds 30               # needs #843
```
`scripts/ab-cores.sh` is the A/B core test as a single script: it alternates the two settings, waits for the battery to cool before each step, and puts your prefs back afterwards. It is a cleaned-up merge of the scripts that produced the numbers above; it has been syntax-checked but not run in this exact form.
