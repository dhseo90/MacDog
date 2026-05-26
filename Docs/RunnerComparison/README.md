# Runner Comparison

This directory is for generated Pup/Bot comparison images after final Codex Bot assets are installed.

The previous code-drawn Bot comparison image was removed because it was not product-quality. Do not keep placeholder Bot art here.

To compare a replacement Bot runner:

1. Add `bot-runner-0.png` through `bot-runner-7.png` under `Sources/CodexUsageMonitor/Resources/Runner/Bot`.
2. Run `./script/verify_runner_baseline.sh`.
3. Run:

```sh
./script/render_runner_comparison.sh
```

4. Review the generated `pup-vs-bot.png` at 16 pt, 18 pt, and 22 pt.

Codex Bot should only become a user-facing `Runner character` option if it is clearly distinct and product-quality at menu bar size.
