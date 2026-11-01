# Proposed Lebanese ingredient identities

`lebanese-ingredients.proposed.json` contains 130 proposed identities, not database
records or an import payload. All 130 require manual review. Nothing reads this
file automatically at application startup.

Keys are stable across environments; PostgreSQL IDs are not. Do not regenerate a
key from an edited display name. A meaningfully different edible state, grade or
formulation needs a distinct key. The starting selection supports Lebanese mezze,
salads, lentil dishes, stews, stuffed vegetables, kafta, tawook and baked kibbeh,
with some bread/dessert ingredients for later recipes. It is not a complete food
taxonomy or a promise that every entry has a suitable USDA record.

Every `existingIngredientId` and `nutritionCandidate` is null. The separate
`candidateExistingIngredientIds` list records possibilities requiring user
approval; it must never be interpreted as an approved binding. Duplicate legacy
IDs and unknown food states remain unresolved. Existing IDs 8 and 11 are excluded
from proposed bindings, without altering their records or references.

All Arabic names and aliases are draft translations requiring Lebanese editorial
review. English aliases are explicit suggestions; normalize case, Unicode and
spacing for lookup without collapsing food-state/grade/formulation distinctions.
Supplier bulgur grading is not universal. The proposed fish species, meat fat,
milk composition and mixed-spice formulations require confirmation before mapping.

`g` is a proposed default for **measured edible mass**, not a conversion rule.
Whole produce can have shopping weight different from usable recipe mass. Cooked,
drained, peeled and hollowed states must be weighed in that state. No density,
piece/clove weight, hydration factor or raw-to-cooked yield is assumed. Even water
has no automatic nutrition bypass under the current calculation policy.

USDA candidates must be independently reviewed against the exact identity, state,
edible portion and supported Foundation/SR Legacy record. Use the existing
JWT-plus-curator mapping workflow after approval; never populate trusted nutrient
values from this proposal. Allergen and dietary reviews remain independent. No
allergen classifications or nutrient values are present in this catalog.

Validate the proposal from `backend/backend`:

```powershell
./scripts/Test-IngredientCatalog.ps1
```

Checkpoint A does not authorize database bindings, catalog insertion, recipe
publication, source/license schema work, or an importer. Review the checkpoint
report before approving those later scopes.
