"""Offline negative and positive checks for reviewed-history validation."""
import unittest
from audit_history import validate

class HistoryTests(unittest.TestCase):
    def setUp(self):
        self.sha = "a" * 40
        self.record = {"sha": self.sha, "purpose": "Independent engineering slice", "verification": "Strict tests passed"}
        self.facts = {self.sha: {"paths": ["decoder.mbt"], "parents": 1, "author": "red6667", "committer": "red6667"}}

    def test_accepts_reviewed_nonempty_slice(self):
        accepted, errors = validate([self.record], self.facts, "red6667")
        self.assertEqual(len(accepted), 1)
        self.assertEqual(errors, [])

    def test_rejects_duplicates_missing_and_unreachable(self):
        for records in [[self.record, self.record], [dict(self.record, purpose="")], [dict(self.record, sha="bad")], [dict(self.record, sha="b"*40)]]:
            self.assertTrue(validate(records, self.facts, "red6667")[1])

    def test_rejects_empty_merges_and_wrong_identity(self):
        for overrides in [{"paths": []}, {"parents": 2}, {"author": "other"}, {"committer": "other"}]:
            facts = {self.sha: dict(self.facts[self.sha], **overrides)}
            self.assertTrue(validate([self.record], facts, "red6667")[1])

if __name__ == "__main__":
    unittest.main()
