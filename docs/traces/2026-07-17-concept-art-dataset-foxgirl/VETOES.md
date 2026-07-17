# Vetoed generations — concept-art dataset sweep

Human-in-the-loop curation record for the 6-feature x 20-image dataset.
Each rejected wave triggered a prompt or design revision (recorded in
`plan.jsonld`); vetoed images are preserved in the `rejected_*`
subdirectories rather than deleted so the failure modes stay inspectable.

| Wave | Dir | Count | Defect (user veto) | Fix applied |
|---|---|---|---|---|
| v1 | `rejected_v1_childlike/` | 4 | "chibi gremlin child look" — z-image-turbo's default proportions for this prompt | added `adult woman, mature proportions` positively + `child, chibi, toddler, big head small body, gremlin, childlike proportions` negatively; chibi feature replaced with knight_armor |
| v2 | `rejected_v2_underwear_drift/` | 8 | adult-proportions fix overcorrected to underwear/bikini in features with no outfit terms (autumn_sunset) | outfit terms added to autumn_sunset + baseline prompts; `underwear, bikini, swimsuit, lingerie, panties` added negatively |
| v2 | `rejected_v2_prompt_revision/` | 12 | baseline stayed clothed but drifted cutesy; one render (s05) had **two tails** despite the negative prompt | same prompt revision; archived wholesale to keep the feature's distribution consistent under the revised prompt |
| v2.1 | `rejected_v2_1_composite_features/` | 8 | features were composites (hair+outfit+setting deltas at once) — user: fewer features per image is easier to control | v3 atomic-feature redesign: one attribute delta per feature vs a fixed baseline |

Earlier per-seed vetoes from the exploratory sweep (fox-head-as-tail, two
tails) are recorded in
`../2026-07-17-latent-space-foxgirl/rejected/VETOES.md`; those became the
core of the shared negative prompt used here.

Final per-image QA of the v3 output happens after the sweep completes; any
further vetoes will be appended to this table.
