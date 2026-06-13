# Contributing

Contributor workflow lives in **[dev-docs/CONTRIBUTING.md](dev-docs/CONTRIBUTING.md)**.

Quick gate after clone:

```bash
./scripts/install-git-hooks.sh
CI_HEADLESS=1 ./scripts/run-tests.sh --tier a
```

Read [docs/SAFETY.md](docs/SAFETY.md) before popup, scheduler, or config changes.
