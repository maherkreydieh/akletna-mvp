"""Offline recipe staging only. Never connects to an API or database."""
import argparse
import copy
import hashlib
import json
from decimal import Decimal, InvalidOperation
from datetime import date
from pathlib import Path
from urllib.parse import urlparse

LICENSES = {"CC0-1.0", "CC-BY-4.0", "CC-BY-SA-4.0", "ORIGINAL-AKLETNA"}
UNITS = {"g", "kg", "mL", "L", "cup", "tbsp", "tsp", "piece"}


def nonblank(value):
    return isinstance(value, str) and bool(value.strip())


def https(value):
    try:
        parsed = urlparse(value) if isinstance(value, str) else None
        return parsed is not None and parsed.scheme == "https" and bool(parsed.hostname) and not parsed.username and not parsed.password
    except ValueError:
        return False


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest()


def stage(batch, mappings=None, known=None):
    """Return review data, never a publish command. IDs require explicit reviewed mapping."""
    if not isinstance(batch, dict) or type(batch.get("schemaVersion")) is not int or batch.get("schemaVersion") != 1 or not isinstance(batch.get("recipes"), list):
        raise ValueError("Expected schemaVersion 1 and recipes array")
    mappings = {} if mappings is None else mappings
    known = {} if known is None else known
    if not isinstance(mappings, dict) or not isinstance(known, dict):
        raise ValueError("Mapping and known manifests must be objects")
    for field in ("sourceKeys", "contentHashes"):
        values = known.get(field, [])
        if not isinstance(values, list) or any(not isinstance(v, str) for v in values):
            raise ValueError("Known manifest values must be arrays of strings")
    seen_sources = set(known.get("sourceKeys", []))
    seen_hashes = set(known.get("contentHashes", []))
    entries = []
    for raw in batch["recipes"]:
        issues, warnings = [], []
        if not isinstance(raw, dict):
            entries.append({"status": "QUARANTINED", "issues": ["INVALID_RECIPE_OBJECT"], "source": raw})
            continue
        recipe = copy.deepcopy(raw)
        quality_issues = recipe.get("sourceQualityIssues", [])
        if not isinstance(quality_issues, list) or any(not isinstance(v, str) for v in quality_issues):
            issues.append("INVALID_SOURCE_QUALITY_ISSUES")
        elif quality_issues:
            issues.append("SOURCE_QUALITY_REVIEW_REQUIRED")
        provenance = recipe.get("provenance") or {}
        if not isinstance(provenance, dict):
            issues.append("INVALID_PROVENANCE_OBJECT")
            provenance = {}
        for field in ("url", "revisionUrl", "historyUrl", "licenseUrl"):
            if not https(provenance.get(field)):
                issues.append("PROVENANCE_" + field.upper())
        for field in ("attribution", "retrievedOn", "changes"):
            if not isinstance(provenance.get(field), str) or not provenance[field].strip():
                issues.append("PROVENANCE_" + field.upper())
        try:
            date.fromisoformat(provenance.get("retrievedOn", ""))
        except (TypeError, ValueError):
            issues.append("INVALID_RETRIEVAL_DATE")
        if not isinstance(provenance.get("license"), str) or provenance.get("license") not in LICENSES:
            issues.append("UNAPPROVED_TEXT_LICENSE")
        if not nonblank(recipe.get("name")) or not 2 <= len(recipe["name"]) <= 150:
            issues.append("INVALID_NAME")
        servings = recipe.get("servings")
        if type(servings) is not int or not 0 < servings <= 2147483647:
            issues.append("MISSING_OR_INVALID_SERVINGS")
        steps = recipe.get("steps")
        if not isinstance(steps, list) or not steps or any(not isinstance(s, str) or not s.strip() for s in steps):
            issues.append("MISSING_STEPS")
        elif len("\n".join(steps)) > 20000:
            issues.append("INSTRUCTIONS_TOO_LONG")
        ingredients = recipe.get("ingredients")
        if not isinstance(ingredients, list) or not 1 <= len(ingredients) <= 100:
            issues.append("INVALID_INGREDIENT_LIST")
            ingredients = []
        mapped = []
        for index, item in enumerate(ingredients):
            prefix = "INGREDIENT_" + str(index + 1) + "_"
            if not isinstance(item, dict):
                issues.append(prefix + "INVALID_OBJECT")
                continue
            key = item.get("key")
            if not isinstance(key, str) or not key.strip() or not nonblank(item.get("sourceText")):
                issues.append(prefix + "MISSING_SOURCE_IDENTITY")
            quantity = item.get("quantity")
            try:
                # JSON floats are deliberately rejected; source decimals must remain exact strings.
                if not isinstance(quantity, str):
                    raise ValueError()
                number = Decimal(quantity)
                if not number.is_finite() or number <= 0 or number.adjusted() >= 12 or number.as_tuple().exponent < -12:
                    raise ValueError()
            except (ValueError, InvalidOperation):
                issues.append(prefix + "UNRESOLVED_QUANTITY")
            if not isinstance(item.get("unit"), str) or item.get("unit") not in UNITS:
                issues.append(prefix + "UNRESOLVED_UNIT")
            mapping = mappings.get(key) if isinstance(key, str) else None
            if not isinstance(mapping, dict) or type(mapping.get("ingredientId")) is not int or not 0 < mapping["ingredientId"] <= 9223372036854775807 or not nonblank(mapping.get("reviewedBy")) or not nonblank(mapping.get("preparationState")):
                issues.append(prefix + "UNREVIEWED_MAPPING")
            elif mapping.get("unit") != item.get("unit"):
                issues.append(prefix + "MAPPING_UNIT_MISMATCH")
            else:
                mapped.append({"ingredientId": mapping["ingredientId"], "quantity": quantity, "unit": item.get("unit")})
        image = recipe.get("image")
        if not image:
            warnings.append("NO_PHOTO")
        elif not isinstance(image, dict) or not isinstance(image.get("license"), str) or image.get("license") not in LICENSES or any(not https(image.get(k)) for k in ("url", "sourceUrl", "licenseUrl")) or not nonblank(image.get("attribution")):
            issues.append("UNVERIFIED_IMAGE_RIGHTS")
        warnings.extend(["NUTRITION_UNMAPPED", "OWNER_REVIEW_REQUIRED"])
        content = {k: recipe.get(k) for k in ("name", "servings", "steps", "ingredients")}
        content_hash = digest(content)
        source_key = provenance.get("url") if isinstance(provenance.get("url"), str) else None
        duplicate = source_key in seen_sources or content_hash in seen_hashes
        if source_key:
            seen_sources.add(source_key)
        seen_hashes.add(content_hash)
        entries.append({"status": "DUPLICATE" if duplicate else "QUARANTINED" if issues else "READY_FOR_REVIEW",
                        "issues": issues, "warnings": warnings, "sourceKey": source_key,
                        "contentHash": content_hash, "provenanceHash": digest(provenance),
                        "recipe": recipe, "mappedIngredients": mapped})
    return {"schemaVersion": 1, "publicationAllowed": False, "entries": entries}


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("batch")
    parser.add_argument("output")
    parser.add_argument("--mappings")
    parser.add_argument("--known", help="Previously reviewed sourceKeys/contentHashes manifest")
    args = parser.parse_args()
    result = stage(read(args.batch), read(args.mappings) if args.mappings else None, read(args.known) if args.known else None)
    target = Path(args.output)
    # Exclusive create protects a previous review or any other existing file.
    with target.open("x", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2, ensure_ascii=False, allow_nan=False)
        handle.write("\n")
    counts = {status: sum(e["status"] == status for e in result["entries"]) for status in ("READY_FOR_REVIEW", "QUARANTINED", "DUPLICATE")}
    print(json.dumps(counts))


if __name__ == "__main__":
    main()
