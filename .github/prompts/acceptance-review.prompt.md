---
description: 'Review the Strumok rewrite against the acceptance checklist and compatibility contracts; report pass/fail per item.'
argument-hint: 'Optional scope, e.g. "compatibility" or "M5"'
agent: 'agent'
---

Review the current state of the repository against [acceptance](../instructions/acceptance.instructions.md)
(scope: ${input:scope:all}).

For each checklist item:
1. Find the implementing code and tests; run the relevant tests/commands where possible.
2. For compatibility items, verify against the contracts:
   - [spec-02](../instructions/spec-02-content-suppliers-ffi.instructions.md) and the checksums in
     [contract.md](../skills/rust-supplier-bridge/references/contract.md);
   - [spec-03](../instructions/spec-03-collection-and-firebase-sync.instructions.md) (JSON keys, enum spellings, merge rules);
   - [spec-04](../instructions/spec-04-auth-and-tv-pairing.instructions.md) (endpoints, headers, body).
3. Mark the item ✅ pass, ❌ fail (with file/line evidence), or ⚠️ needs manual check (state what to check on which device).

Output a table `| Item | Status | Evidence / next step |`, then a short prioritized list of fixes. Do not change code.
