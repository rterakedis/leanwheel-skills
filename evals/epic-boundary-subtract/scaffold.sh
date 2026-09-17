#!/usr/bin/env bash
# Seeds the run's empty workspace with the shared `sampleapp` fixture (evals/fixtures/sampleapp).
# Runs only with `claude plugin eval --scaffold`.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fixtures/sampleapp" && pwd)"
cp -R "$src/." .
