# AgentKit

Drive a Godot 4 project from the CLI: capture, flows, node inspection, HTTP fetch, PNG diff. See the Spanish README in `rc-v0.10.0-spanish` for the full text.

## Determinism

Smoke bench for simulations: `addons/agent_kit/determinism/`. A `DetRecorder` node records the run into a sha256 and `det_run.sh` compares the digest across clocks (`fixed`, `fixed2`, `stress`, `window`) and against a stored baseline.

```bash
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt quick --no-window   # smoke on every slice
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt bless               # re-record the baseline after an intentional change
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt table               # verdict from what is on disk
```

- Cases in `agent/det_cases.txt` (`name|args|quick|set`), config in `agent/det.cfg` (`DET_SCENE`, `DET_OUT`, `DET_BASELINE`).
- Every Godot goes through `harness/godot_run.sh` (FIFO queue). No window runs in parallel with the bench; a run flagged `CONTAMINATED` or with a `watchdog` does not count.
- It is a smoke test, not byte-exact: when a digest moves because of an intentional change, check that `fixed` and `fixed2` agree and re-record with `bless`.
- Self-test without a game: `det_selftest.sh`. Full guide: skill `godot-determinism`.
