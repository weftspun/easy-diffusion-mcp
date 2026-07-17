# Session traces

JSON-LD records of notable work sessions, generated with
[taskweft](https://github.com/taskweft/taskweft)'s HTN planner
(`mcp__taskweft__validate` / `plan`). Each dated subdirectory holds three
separate documents:

- `domain.jsonld` — the reusable `domain:Definition` (actions/methods). Each
  action carries a real ISO 8601 `duration` (ex: `PT7M1S`), not a placeholder.
- `problem.jsonld` — the `domain:Problem` instance for that session (state + `todo_list`)
- `plan.jsonld` — the planner's output for that problem (resolved plan, solution
  tree, status, and the duration-relative `temporal` STN block). It also adds
  a `civil_time` block anchoring `PT0S` to an absolute origin timestamp and
  giving each step's real-world start/end — this is this file's own
  annotation, **not** taskweft output: the domain/problem schema has no
  absolute-datetime field (`mcp__taskweft__validate` rejects one). Each
  `civil_time` step records its `source` (a real log/git/GitHub timestamp, or
  `"approximate"` where no finer-grained record exists).
