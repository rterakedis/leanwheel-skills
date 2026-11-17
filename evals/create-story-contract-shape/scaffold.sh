#!/usr/bin/env bash
# Seeds the run's empty workspace with the `planapp` fixture (evals/fixtures/planapp).
# Runs only with `claude plugin eval --scaffold`.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fixtures/planapp" && pwd)"
cp -R "$src/." .
