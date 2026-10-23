# Working on TangCore

These rules apply to every repository in the project. Each repository also has its own `AGENTS.md` with what's specific to it (how to build it, its simulations, its clocks); read both.

## The project

TangCore runs classic consoles on the Sipeed Tang Console. It has two halves that talk over a 2 Mbaud UART with a framed protocol:
- **Firmware** on the board's BL616 microcontroller: the menu, the SD card, USB, game saves, and loading a core into the FPGA over JTAG.
- **FPGA cores**, one per console: nestang (NES), snestang (SNES), gbatang (GBA), mdtang (Genesis), smstang (Master System / Game Gear), plus monitorcore (the menu's own FPGA design).

The **Tang Console 138K is the board we work on.** Builds for the Console 60K must keep working where they already do, but 60K-only problems are filed as issues with the `console60k` label and not worked on for now.

## Repositories and branches

Use only the cassiostp forks:

| Repo | Default branch |
|---|---|
| cassiostp/tangcore (this repo: docs, CI, submodules) | main |
| cassiostp/firmware-bl616 | master |
| cassiostp/nestang, cassiostp/mdtang, cassiostp/smstang | master |
| cassiostp/snestang, cassiostp/gbatang | main |
| cassiostp/monitorcore | master |

- **Never push to, open issues or PRs on, or comment on the upstream nand2mario repositories** (or any other upstream). Reading them is fine. When referring to an upstream issue or file, wrap it in backticks (`` `nand2mario/snestang#12` ``), so GitHub doesn't create a backlink.
- Branch names: `fix/<topic>`, `feature/<topic>`, `exp/<topic>` for experiments and scratch work, `docs/<topic>`.
- Integration branches belong to whoever coordinates the round: `int/<round>` collects the fixes for the next hardware test, and `qa/<round>` is the exact build being tested on hardware. Don't push to them unless you're told to, and never rewrite them: a `qa/*` branch must stay reproducible.
- Never push to `main`/`master` directly. Changes get there by pull request.

## Ground rules

- **Never flash or touch the hardware.** The user does all hardware testing. Never touch the Sipeed partner image at flash address 0x0.
- **Never commit, upload or redistribute the Gowin toolchain.**
- **ROMs:** test ROMs live on the user's machine (`~/tangcore-test-bundle/test roms/`). Use them only in local simulations. Never commit, push or upload a ROM, or anything derived from one: frames, audio, save files, hashes of their contents.
- **The Docker daemon is shared** by many agents. Give every container a unique `--name`, and stop only containers you started, by name. Never run anything like `docker kill $(docker ps -q)`: that has killed other agents' simulations and a model server before.
- **Games must never run slower than on the original console**, and as close to its speed as possible. The HDMI output runs at each console's own refresh rate (NES/SNES 60.11 Hz, Genesis/SMS 59.93 Hz, GBA 59.75 Hz): the 720p line length is changed, and each core is halt-locked to it. Standard 60 Hz stays selectable for displays that refuse a native rate. Any change that affects game speed, the CPU's time per frame or audio pitch must say so.

## Where things are recorded

- **Git is the source of truth.** Put the reasoning in commit messages and PR descriptions. Don't keep a parallel history in docs or notes.
- **Bugs and planned work are GitHub issues:** firmware ones in cassiostp/firmware-bl616, everything else (cores, tooling, docs) in cassiostp/tangcore. Link PRs to them (`Fixes #n`) so they close on merge.
- **Docs describe the current state only.** No changelogs, no dated write-ups, and no bugs in docs, except hardware limitations that can't be worked around. If a doc is wrong, fix the doc.
- **Hardware and firmware findings** (pinouts, protocol quirks, clock facts, debug setups) go in the field notes at `~/tangcore-notes/` on the user's machine, a local git repo. Tag each claim Verified, Observed or Unverified, with its source, and commit.

## Building and testing

The host is arm64 Linux.

**FPGA cores** build on GitHub Actions, from tangcore's `ci/core-builds` branch:

```sh
gh workflow run cores.yml -R cassiostp/tangcore --ref ci/core-builds \
  -f core=<nestang|snestang|gbatang|mdtang|smstang|monitorcore> -f ref=<branch> -f board=<console138k|console60k>
```

- The build fails on any setup or hold violation.
- The artifact has `<core>-<board>/<core>.bin` and the timing and utilisation reports.
- Runs for the same core, ref and board cancel each other: wait for one to finish before starting the same build again.

**Save simulations for all cores:**

```sh
gh workflow run sims.yml -R cassiostp/tangcore --ref ci/sim-tests -f core=all -f ref=<branch>
```

**Firmware:**
- `gh workflow run build.yml -R cassiostp/firmware-bl616 --ref <branch>` builds the image.
- `gh workflow run host-sim.yml -R cassiostp/firmware-bl616 --ref <branch>` runs the host simulator. Its `core_ref` input picks which core branches the RTL suites build, so pass the one you mean.
- The host simulator also runs locally (`bash host/run-tests.sh`, `--rtl-<core>`); see firmware-bl616's `AGENTS.md`.

**Local simulations:**
- Each bench in a core's `sim/` has a `run.sh`; the larger ones also have a README, and the repository's own `AGENTS.md` lists them.
- iverilog runs in the local arm64 image `tangcore-iv:1` (Icarus 12); Verilator runs in `verilator/verilator`. Run them as `docker run --rm --name <yourtask>_<bench> --user $(id -u):$(id -g) ...`, so outputs aren't root-owned.
- The sim scripts start their containers through `$DOCKER_RUN`: `simrun` when it's on the PATH (an optional local helper that adds a persistent ccache volume and full parallelism; it isn't part of these repositories), plain `docker run --rm` otherwise. Set `SIM_PREFIX=<yourtask>` so their container names are yours and parallel runs don't clash.
- `hdlc/iverilog` is amd64-only and doesn't run here.

**GitHub gotchas:**
- The gh token can't push `.github/workflows/*` files. Push those over SSH: `git push git@github.com:cassiostp/<repo>.git <branch>`.
- A workflow that exists only on a side branch must fire once on push before `gh workflow run` can dispatch it.

**Gowin and GW5A facts learned the hard way:**
- A project reads only one SDC file, and a second `add_file -type sdc` is silently ignored. Give each board one complete SDC, and check that its clocks match the PLL outputs.
- The GW5AST-138 has no distributed/SSRAM, so asynchronous-read RAMs become flip-flops.
- P&R is deterministic for the same inputs.
- `set_option -vhdl_std vhd2008` accepts the srg320 VHDL (SA-1 and others) unchanged.
- The PLL feedback divider takes fractional values in 1/8 steps; the output dividers are integer only.

## Commits and pull requests

- End every commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, whatever model you are.
- End every PR description with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Open PRs with an explicit repo and base: `gh pr create -R cassiostp/<repo> --base <branch>`.
- PRs, issues and issue comments are outward-facing. Agents working from a brief don't open them unless the brief says to; the coordinator does.
- Match the surrounding code: its comment density, naming and idiom.

## Reporting

When you report on work (a report file, a PR description, an issue comment):
- Mark each claim **Verified** (you read the code, ran it, or saw a CI result: cite file:line, the command, or the run ID) or **Unverified** (inference).
- Give before/after numbers for anything measured: timing margins, utilisation, sim results.
- List what only hardware can answer, and short hardware checks: the game, what to do, and what to expect.

## Coordinating other agents

When one agent hands work to others:
- Put briefs in files, and give each agent its own work directory with fresh clones. Never share a checkout between agents.
- Tell agents to wait for simulations and CI by polling in their shell (`gh run watch <id> --exit-status`, or a sleep loop), not by ending their turn. Some models end the turn while a job is still running, and the work is lost.
- Before re-dispatching an agent that stopped, check what it already pushed (`git ls-remote`), its work directory, and any processes it left running, so the next one continues instead of redoing or duplicating work.
- Review every result before it's merged into an integration branch.
