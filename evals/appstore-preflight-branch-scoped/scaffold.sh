#!/usr/bin/env bash
# Seeds the run's empty workspace with the shared `storeapp` fixture (evals/fixtures/storeapp).
# Runs only with `claude plugin eval --scaffold`.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fixtures/storeapp" && pwd)"
cp -R "$src/." .
