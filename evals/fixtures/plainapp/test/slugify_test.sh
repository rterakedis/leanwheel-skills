#!/usr/bin/env bash
source "$(dirname "$0")/../lib/slugify.sh"
[ "$(slugify 'Hello, World!')" = "hello-world" ] || { echo "FAIL basic"; exit 1; }
echo ok
