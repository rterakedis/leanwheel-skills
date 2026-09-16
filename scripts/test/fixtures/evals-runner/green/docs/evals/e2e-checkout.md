# Cases written inside a fence must parse the same as bare ones

```
### EVAL e2e.checkout-1 — fenced case
type: command
enabled: true
run: echo ok
expect: exit-0
```
