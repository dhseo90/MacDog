# Runner Baseline

This document fixes the current Codex Pup runner as the app runner baseline.

## Codex Pup

- Asset path: `Sources/MacDog/Resources/Runner`
- Frame files: `pup-runner-0.png` through `pup-runner-7.png`
- Frame count: 8
- Frame size: 80x48 px
- Menu bar status item length: 38 pt
- Popover size: 320x540 pt
- Default runner speed basis: weekly usage

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

Use this baseline before changing runner assets.
