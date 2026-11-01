import copy
import unittest
from stage_recipes import stage


def fixture():
    return {"name": "Synthetic test recipe", "servings": 2, "steps": ["Mix."],
            "ingredients": [{"key": "test", "sourceText": "1 g test", "quantity": "1.000000000001", "unit": "g"}],
            "provenance": {"url": "https://example.invalid/recipe", "revisionUrl": "https://example.invalid/r1", "historyUrl": "https://example.invalid/history", "licenseUrl": "https://creativecommons.org/publicdomain/zero/1.0/", "license": "CC0-1.0", "attribution": "Synthetic test only", "retrievedOn": "2026-10-30", "changes": "Test"}}


class StagingTests(unittest.TestCase):
    def run_stage(self, recipe=None, mappings=None, known=None):
        return stage({"schemaVersion": 1, "recipes": [recipe or fixture()]}, mappings, known)["entries"][0]

    def mapping(self):
        return {"test": {"ingredientId": 12, "unit": "g", "reviewedBy": "test reviewer", "preparationState": "raw"}}

    def test_exact_decimal_ready_never_published(self):
        recipe = fixture()
        before = copy.deepcopy(recipe)
        result = stage({"schemaVersion": 1, "recipes": [recipe]}, self.mapping())
        self.assertFalse(result["publicationAllowed"])
        self.assertEqual(result["entries"][0]["status"], "READY_FOR_REVIEW")
        self.assertEqual(result["entries"][0]["mappedIngredients"][0]["quantity"], "1.000000000001")
        self.assertEqual(recipe, before)

    def test_missing_mapping_quarantined(self):
        self.assertIn("INGREDIENT_1_UNREVIEWED_MAPPING", self.run_stage()["issues"])

    def test_invalid_quantities(self):
        for quantity in [None, 1.2, "NaN", "Infinity", "0", "-1", "2-3", "to taste", "0.0000000000001", "1000000000000"]:
            with self.subTest(quantity=quantity):
                recipe = fixture()
                recipe["ingredients"][0]["quantity"] = quantity
                self.assertIn("INGREDIENT_1_UNRESOLVED_QUANTITY", self.run_stage(recipe)["issues"])

    def test_unsupported_units_and_mismatch(self):
        recipe = fixture()
        recipe["ingredients"][0]["unit"] = "bunch"
        self.assertIn("INGREDIENT_1_UNRESOLVED_UNIT", self.run_stage(recipe)["issues"])
        recipe["ingredients"][0]["unit"] = "mL"
        self.assertIn("INGREDIENT_1_MAPPING_UNIT_MISMATCH", self.run_stage(recipe, self.mapping())["issues"])

    def test_missing_yield_and_steps(self):
        recipe = fixture()
        recipe.update(servings=None, steps=[])
        self.assertIn("MISSING_OR_INVALID_SERVINGS", self.run_stage(recipe)["issues"])
        self.assertIn("MISSING_STEPS", self.run_stage(recipe)["issues"])

    def test_source_and_content_duplicates(self):
        recipe = fixture()
        result = stage({"schemaVersion": 1, "recipes": [recipe, copy.deepcopy(recipe)]})
        self.assertEqual(result["entries"][1]["status"], "DUPLICATE")
        first = result["entries"][0]
        self.assertEqual(self.run_stage(known={"contentHashes": [first["contentHash"]]})["status"], "DUPLICATE")
        self.assertEqual(self.run_stage(known={"sourceKeys": [first["sourceKey"]]})["status"], "DUPLICATE")

    def test_rights_required(self):
        recipe = fixture()
        recipe["provenance"]["license"] = "All rights reserved"
        recipe["provenance"]["revisionUrl"] = "file:///private"
        recipe["image"] = {"url": "https://example.invalid/photo"}
        issues = self.run_stage(recipe)["issues"]
        self.assertIn("UNAPPROVED_TEXT_LICENSE", issues)
        self.assertIn("PROVENANCE_REVISIONURL", issues)
        self.assertIn("UNVERIFIED_IMAGE_RIGHTS", issues)

    def test_malformed_records_do_not_abort_batch(self):
        result = stage({"schemaVersion": 1, "recipes": [None, {"ingredients": [None]}]})
        self.assertTrue(all(e["status"] == "QUARANTINED" for e in result["entries"]))

    def test_bad_envelope_rejected(self):
        with self.assertRaises(ValueError):
            stage({"schemaVersion": 2, "recipes": []})



class MalformedMetadataTests(unittest.TestCase):
    def test_metadata_types_quarantine_instead_of_crashing(self):
        from stage_recipes import stage
        for bad in [42, [], "oops", {"license": [], "url": [], "retrievedOn": "yesterday"}]:
            recipe = fixture()
            recipe["provenance"] = bad
            result = stage({"schemaVersion": 1, "recipes": [recipe]})
            self.assertEqual(result["entries"][0]["status"], "QUARANTINED")
        recipe = fixture()
        recipe["ingredients"][0]["unit"] = []
        recipe["image"] = {"license": []}
        self.assertEqual(stage({"schemaVersion": 1, "recipes": [recipe]})["entries"][0]["status"], "QUARANTINED")

    def test_invalid_manifest_rejected(self):
        for known in [{"sourceKeys": [None]}, {"contentHashes": 1}, [1]]:
            with self.assertRaises(ValueError):
                stage({"schemaVersion": 1, "recipes": []}, known=known)

    def test_cli_protects_existing_output(self):
        import json
        import subprocess
        import sys
        import tempfile
        from pathlib import Path
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "batch.json"
            target = Path(temporary) / "review.json"
            source.write_text(json.dumps({"schemaVersion": 1, "recipes": [fixture()]}), encoding="utf-8")
            command = [sys.executable, "-B", str(Path(__file__).with_name("stage_recipes.py")), str(source), str(target)]
            first = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(first.returncode, 0, first.stderr)
            original = target.read_bytes()
            second = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(second.returncode, 0)
            self.assertEqual(target.read_bytes(), original)


class QualityTests(unittest.TestCase):
    def test_unresolved_quality_blocks_even_with_mappings(self):
        recipe = fixture()
        recipe["sourceQualityIssues"] = ["Cooking trial required"]
        result = stage({"schemaVersion": 1, "recipes": [recipe]}, StagingTests().mapping())
        self.assertIn("SOURCE_QUALITY_REVIEW_REQUIRED", result["entries"][0]["issues"])

    def test_malformed_url_and_backend_integer_bounds(self):
        recipe = fixture()
        recipe["provenance"]["url"] = "https://[broken"
        recipe["servings"] = 2147483648
        result = stage({"schemaVersion": 1, "recipes": [recipe]})
        self.assertIn("PROVENANCE_URL", result["entries"][0]["issues"])
        self.assertIn("MISSING_OR_INVALID_SERVINGS", result["entries"][0]["issues"])



class StrictContractTests(unittest.TestCase):
    def test_schema_version_requires_exact_int_one(self):
        for version in [True, False, 1.0, "1", None]:
            with self.subTest(version=version), self.assertRaises(ValueError):
                stage({"schemaVersion": version, "recipes": []})

    def test_falsey_non_object_manifests_rejected(self):
        for value in [[], 0, False, ""]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                stage({"schemaVersion": 1, "recipes": []}, mappings=value)
            with self.subTest(value=value), self.assertRaises(ValueError):
                stage({"schemaVersion": 1, "recipes": []}, known=value)
        self.assertEqual(stage({"schemaVersion": 1, "recipes": []}, {}, {})["entries"], [])

    def test_nonblank_name_and_source_text(self):
        recipe = fixture()
        recipe["name"] = "   "
        result = StagingTests().run_stage(recipe, StagingTests().mapping())
        self.assertIn("INVALID_NAME", result["issues"])
        for value in ["   ", ["truthy"], {"truthy": True}, 1, None]:
            recipe = fixture()
            recipe["ingredients"][0]["sourceText"] = value
            before = copy.deepcopy(recipe)
            result = StagingTests().run_stage(recipe, StagingTests().mapping())
            self.assertIn("INGREDIENT_1_MISSING_SOURCE_IDENTITY", result["issues"])
            self.assertEqual(result["status"], "QUARANTINED")
            self.assertEqual(result["recipe"], before)
            self.assertEqual(recipe, before)

    def test_review_identity_and_preparation_require_text(self):
        for field in ["reviewedBy", "preparationState"]:
            for value in [" ", ["truthy"], {"truthy": True}, 1, None]:
                mappings = StagingTests().mapping()
                mappings["test"][field] = value
                result = StagingTests().run_stage(mappings=mappings)
                self.assertIn("INGREDIENT_1_UNREVIEWED_MAPPING", result["issues"])
                self.assertEqual(result["status"], "QUARANTINED")

    def test_ids_fit_positive_java_long(self):
        for value in [0, -1, True, 1.0, "1", 9223372036854775808]:
            mappings = StagingTests().mapping()
            mappings["test"]["ingredientId"] = value
            result = StagingTests().run_stage(mappings=mappings)
            self.assertIn("INGREDIENT_1_UNREVIEWED_MAPPING", result["issues"])
        mappings = StagingTests().mapping()
        mappings["test"]["ingredientId"] = 9223372036854775807
        self.assertEqual(StagingTests().run_stage(mappings=mappings)["status"], "READY_FOR_REVIEW")

    def test_image_attribution_requires_nonblank_text(self):
        for value in [" ", ["truthy"], {"truthy": True}, 1, None]:
            recipe = fixture()
            recipe["image"] = {"url": "https://example.invalid/photo.jpg", "sourceUrl": "https://example.invalid/source", "licenseUrl": "https://creativecommons.org/publicdomain/zero/1.0/", "license": "CC0-1.0", "attribution": value}
            result = StagingTests().run_stage(recipe, StagingTests().mapping())
            self.assertIn("UNVERIFIED_IMAGE_RIGHTS", result["issues"])
            self.assertEqual(result["status"], "QUARANTINED")


if __name__ == "__main__":
    unittest.main()
