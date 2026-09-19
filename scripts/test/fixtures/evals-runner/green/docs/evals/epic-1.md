# Green fixture — every enabled command case must pass

### EVAL 1.1-1 — shared command, first needle
type: command            # trailing comment on an enum field must be stripped
origin: story 1.1 AC1
enabled: true
run: echo "CartTotalTests passed"; echo "SuiteB passed"
expect: output-contains:"CartTotalTests"

### EVAL 1.1-2 — shared command, second needle (batched with 1.1-1)
type: command
enabled: true
run: echo "CartTotalTests passed"; echo "SuiteB passed"
expect: output-contains:"SuiteB"

### EVAL 1.2-1 — exit code gate
type: command
enabled: true
run: true
expect: exit-0

### EVAL 1.2-2 — regex gate
type: command
enabled: true
run: printf 'Executed 42 tests\n'
expect: output-matches:/Executed [0-9]+ tests/

### EVAL 1.2-3 — needle containing a hash is kept verbatim
type: command
enabled: true
run: echo "# heading"
expect: output-contains:"# heading"

### EVAL 1.3-1 — pending case is skipped, never run
type: command
enabled: false
# pending: write CheckoutTests
run: exit 1
expect: exit-0

### EVAL 1.3-2 — judge case is counted, never run
type: judge
enabled: true
target: git diff -- Sources/Cart.swift
rubric: |
  - copy reads naturally

### EVAL 1.4-1 — escaped quote inside the needle (Swift Testing suite line)
type: command
enabled: true
run: echo '✔ Suite "CapacityBar target floor" passed after 0.1 seconds.'
expect: output-contains:"CapacityBar target floor\" passed"

### EVAL 1.4-2 — a -only-testing: command that DOES run tests is untouched
type: command
enabled: true
run: echo 'xcodebuild -only-testing:AppTests/CapacityBarTests'; echo 'Executed 3 tests, with 0 failures'
expect: exit-0
