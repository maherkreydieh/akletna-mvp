# Day 27 audit — in progress

Baseline: committed Day 26 `9508b47`. This session inherited uncommitted Day 27 work and preserved it. Findings originated in source inspection; the corrected behavior has now been exercised with MVC tests and disposable PostgreSQL/HTTP concurrency tests. No critical issue has been confirmed. Final session evidence and remaining limitations are recorded in `PROJECT_STATUS.md`.

| Severity | Finding | Planned verification / correction |
|---|---|---|
| High | Registration checks email before insertion but the users table has no unique email constraint. Concurrent registration can create ambiguous identities. | Add a guarded additive constraint and race test; preserve existing rows or fail safely if duplicates exist. |
| High | The JWT filter accepts a signed subject without resolving the current account. Deleted-account tokens can still access shared ingredient and curator routes. | Validate the current account and bind its ID to the signed claim; exercise deleted and recreated accounts. |
| Medium | Private recipe mutation returns a different error from a nonexistent recipe. | Align hidden-resource errors while retaining public/curated authorization checks. |
| Medium | Recipe ingredient mutation has no encompassing transaction/parent lock; meal slots have no unique database constraint. | Serialize recipe mutations; verify database constraints and concurrent requests. |
| Medium | Password byte length and several persisted text lengths are not validated; malformed HTTP requests can reach the generic 500 handler. | Bound input at the actual storage/encoder limits and test safe HTTP errors. |
| Medium | Grocery GET creates a row when none exists. | Make the read observational and synchronize the empty-list DTO with Flutter. |
| Medium | A secure-storage read exception can leave the Dio interceptor incomplete; failed login can retain an older session. | Deterministic failure tests and explicit completion/session cleanup. |
| Low | Some mutation buttons rely only on the next widget rebuild to disable repeated callbacks. | Inspect callbacks and add guards where a duplicate write is possible. |

Initial exact configured-secret audit: PASS across 353 tracked files, zero new candidates and 837 reachable Git objects. No credential values are recorded here. Final audit must be repeated after changes.

Disposition: the listed findings have focused corrections. The low-severity duplicate guards now cover create/edit, preferences, and shortage callbacks; a rapid-tap test also exposed a stale callback after a fast successful response, now guarded by the authoritative added state. Splash authentication handles secure-storage deletion failure with Retry rather than an unhandled async exception. USDA exponent values cannot bypass stored numeric precision. Existing custom-unit and malformed legacy-data behavior is preserved.

This session independently checked the configured local PostgreSQL/JWT values against working candidates, index/HEAD and reachable objects: PASS. Actual USDA/curator values are absent from process/user/machine environments, local backend configuration and IDE environment entries; their exact-value audits remain unavailable. The older initial-audit statement above is historical evidence, not a new four-credential PASS claim. No credential is recorded or rotated.

Authorization policy checked against controllers, services and tests:

| Resource | Owner/current user | Other authenticated user | No JWT | Curator with valid JWT |
|---|---|---|---|---|
| User profile/preferences | Own profile and preferences only | Cannot select another account through body/query identity | 401 | Same own-account scope |
| Public recipe | Read/save/plan/compare; USER owner may mutate | Read/save/plan/compare; mutation 403 | 401 | CURATED ordinary CRUD remains protected |
| Private recipe | Read/save/plan/mutate for USER owner | Hidden with 404; excluded from discovery/matching/recommendations | 401 | Separate curation does not grant ordinary recipe CRUD |
| Saved recipe | Own bookmark; duplicate save/unsave idempotent | Own bookmark only for readable sources | 401 | Same scope |
| Pantry/meal plan | Own resources | Guessed foreign IDs return 404 | 401 | Same scope |
| Groceries/contributions | Own list/items/sources; server-derived quantities | Foreign item/source IDs return 404 | 401 | Same scope |
| Trusted allergen/nutrition metadata | JWT alone is insufficient | JWT alone is insufficient | 401 even with curator token | Separate correct curator credential required; wrong/disabled token 403 |

Snapshot and contribution historical captures intentionally remain available to their
owning user after later source privacy changes; they do not expose later private
edits. Recommendations, nutrition and pantry scores remain server-derived.

Verification is bounded to the tested MVP scenarios. Full sign-off remains pending
the unavailable configured-credential audits; this document does not claim a
complete penetration test or a dependency-CVE scan.
