# Negative fixture — every case here must be reported as a regression

### EVAL 9.1-1 — red exit code
type: command
enabled: true
run: false
expect: exit-0

### EVAL 9.1-2 — needle absent
type: command
enabled: true
run: echo "something else"
expect: output-contains:"CartTotalTests"

### EVAL 9.1-3 — vacuous pass guard: exit 0, no output
type: command
enabled: true
run: true
expect: output-contains:"anything"

### EVAL 9.1-4 — regex miss
type: command
enabled: true
run: echo "no numbers here"
expect: output-matches:/Executed [0-9]+ tests/

### EVAL 9.1-5 — unparseable expect
type: command
enabled: true
run: true
expect: whatever-nonsense

### EVAL 9.1-6 — enabled with no run (the empty-field IFS regression)
type: command
enabled: true
expect: exit-0

### EVAL 9.1-7 — escaped-quote needle that is absent still fails (matcher stays strict)
type: command
enabled: true
run: echo '✔ Suite "SomeOtherSuite" passed after 0.1 seconds.'
expect: output-contains:"CapacityBar target floor\" passed"

### EVAL 9.1-8 — vacuous -only-testing: target: 0 tests, exit 0, plenty of output
type: command
enabled: true
run: echo 'xcodebuild -only-testing:AppTests/NoSuchType build-for-testing'; echo 'Executed 0 tests, with 0 failures'
expect: exit-0
