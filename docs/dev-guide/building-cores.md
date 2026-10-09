# Building Cores

The core bitstreams for the Tang Console boards are built in the cloud by the
`cores.yml` GitHub Actions workflow in this repository. It downloads the free
**Gowin EDA V1.9.11.03 Education edition** from the vendor CDN on the runner
(the toolchain itself is never committed or redistributed; the Education
edition needs no licence), caches it for later runs, and runs
`gw_sh build.tcl <board>` in the requested core repository
(`cassiostp/nestang`, `snestang`, `gbatang`, `mdtang`, `smstang`).

## Running a build

```bash
# build nestang at its default branch
gh workflow run cores -R cassiostp/tangcore --ref <branch-of-tangcore> -f core=nestang

# build a branch of the core repo, for the 60K console
gh workflow run cores -R cassiostp/tangcore --ref <branch-of-tangcore> \
  -f core=nestang -f ref=<core-branch> -f board=console60k

# watch it
gh run list -R cassiostp/tangcore --workflow cores
gh run watch <run-id> -R cassiostp/tangcore
```

Inputs: `core` (nestang, snestang, gbatang, mdtang, smstang), `ref` (branch,
tag or SHA in `cassiostp/<core>`; empty means the repo's default branch) and
`board` (`console138k` or `console60k`). A synthesis or place-and-route error,
a timing violation, or a missing `.bin` fails the job; the run summary shows
the max-frequency and resource usage of the build. A run takes roughly one to
two hours.

## The artifact

The green run's artifact is named `<core>-<board>` (e.g.
`nestang-console138k`) and contains the bitstream renamed to the file name the
firmware looks for (`nestang.bin`, `snestang.bin`, ...) plus the build log.
Copy the `.bin` to the SD card, in either of the two places the firmware
searches (top priority first):

```
cores/<board>/<core>.bin     # e.g. cores/console138k/nestang.bin
cores/<core>.bin             # e.g. cores/nestang.bin
```

The TangCore firmware programs it onto the FPGA the first time you launch a
ROM for that core.
