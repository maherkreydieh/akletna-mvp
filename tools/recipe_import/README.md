# Offline recipe review staging

Requires Python 3.10+; standard library only. Run from the repository root:

```powershell
python -B -m unittest discover -s tools/recipe_import -v
python -B tools/recipe_import/stage_recipes.py code/data/recipe-acquisition/wikibooks-pilot-v1.json review-new.json
```

The output path must not already exist. The CLI makes no network requests, reads no credentials, and never writes a database. It does not publish a recipe. Failed validation is reported per entry in JSON; the CLI exits successfully when staging completes, including quarantined entries. Invalid JSON/envelopes/manifests or an existing output path fail the command. Inspect entry statuses, not just process exit code.

`--mappings mapping.json` accepts an object keyed by source ingredient key, with values:

```json
{"ingredientId": 123, "unit": "g", "reviewedBy": "actual reviewer", "preparationState": "cooked and drained"}
```

123 is an example only. Verify IDs, preparation state and units against the isolated target catalog; never reuse example IDs or accept reviewedBy as authentication. A manifest records a review decision; it does not authenticate the reviewer. The importer deliberately does not look up live data or infer mass/density. Match keys consistently within a batch and namespace keys if sourcing semantically different ingredients.

`--known known.json` accepts `{"sourceKeys": [], "contentHashes": []}` from prior reviewed imports. Exact source/content matches become DUPLICATE rather than overwrite existing records. This is not a semantic plagiarism/variant detector or database uniqueness check.

All outputs set publicationAllowed=false. READY_FOR_REVIEW only indicates structural checks passed. The owner must verify source rights/history, recipe accuracy, mappings, photos, and attribution delivery. QUARANTINED/DUPLICATE entries cannot be published through this tool. sourceQualityIssues, when nonempty, always blocks the entry. Preserve documented concerns until explicitly resolved by a real reviewer; do not remove them to pass validation.

Quantities are positive decimal strings with at most 12 integer and 12 fractional digits. JSON floats, missing amounts, ranges, NaN and infinity are rejected. Supported units: g, kg, mL, L, cup, tbsp, tsp, piece. No conversions are applied. Other units require an explicit reviewed extension; do not relabel bunch/dash/clove/juice-of as grams or pieces. Do not infer servings from yield count. No nutrition claims are imported.

The pilot JSON contains CC BY-SA 4.0 adaptations of Wikibooks contributors' text with linked histories, license and change statements. All three real examples are deliberately quarantined. Test fixtures are synthetic, not food data. See docs/RECIPE_ACQUISITION_PROGRESS.md for rights, limitations and admin handoff.

Strict contract checks: schemaVersion is integer 1 (not true/1.0); optional manifests must be JSON objects even when empty. Names and source/reviewer/preparation/image-credit text must contain non-whitespace characters. Ingredient IDs must fit positive Java Long (1 through 9223372036854775807). Original recipe records are retained unchanged in review output.
