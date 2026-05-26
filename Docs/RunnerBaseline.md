# Runner Baseline

This document fixes the current Codex Pup runner as the comparison baseline for future character work.

## Codex Pup

- Asset path: `Sources/CodexUsageMonitor/Resources/Runner`
- Frame files: `pup-runner-0.png` through `pup-runner-7.png`
- Frame count: 8
- Frame size: 80x48 px
- Menu bar status item length: 38 pt
- Popover size: 280x310 pt
- Default runner speed basis: weekly usage

## Codex Bot Asset Slot

- Asset path: `Sources/CodexUsageMonitor/Resources/Runner/Bot`
- Frame files: `bot-runner-0.png` through `bot-runner-7.png`
- Expected frame count: 8
- Expected frame size: 80x48 px
- Current status: image assets pending

The previous code-drawn Bot has been removed. Bot can be reviewed again by replacing only the PNG frames in the Bot asset directory.

## Usage Phases

| Phase | Used percent | Meaning |
| --- | ---: | --- |
| Calm | 0-49% | Low pressure |
| Active | 50-79% | Moderate pressure |
| Fast | 80-94% | High pressure |
| Sprint | 95-99% | Near limit |
| Limit | 100%+ | Limit reached |

## Verification

Run:

```sh
./script/verify_runner_baseline.sh
./script/build_and_run.sh --verify
```

Use this baseline before adding another character. Run `./script/render_runner_comparison.sh` only after all eight Bot frames exist. A new runner should only become a user-facing option when it is visually distinct from Codex Pup at 16 pt, 18 pt, and 22 pt menu bar sizes.
