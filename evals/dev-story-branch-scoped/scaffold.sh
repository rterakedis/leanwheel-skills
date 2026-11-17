#!/usr/bin/env bash
# Seeds the run's empty workspace with the `plainapp` fixture (evals/fixtures/plainapp).
# Runs only with `claude plugin eval --scaffold`.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fixtures/plainapp" && pwd)"
cp -R "$src/." .
