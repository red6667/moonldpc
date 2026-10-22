"""Regression tests for numeric-vs-structural oracle regeneration checks."""
import unittest
from generate_oracles import compare_fixtures


class ReproducibilityTests(unittest.TestCase):
    def test_last_ulp_and_formatting_are_not_behavior_changes(self):
        self.assertIsNone(compare_fixtures("f(1, [0.10000000000000002, -2.5],)", "f(1,[0.1,-2.5])"))

    def test_graphs_and_integer_histories_must_match_exactly(self):
        self.assertIsNotNone(compare_fixtures("f(1, [0.1], [1, 0])", "f(2, [0.1], [1, 0])"))
        self.assertIsNotNone(compare_fixtures("f([0.1], [1, 0])", "f([0.1], [1, 1])"))
        self.assertIsNotNone(compare_fixtures("f([0.1, 0.2])", "f([0.1])"))

    def test_numerical_drift_outside_tolerance_is_rejected(self):
        for a, b in [("0.1", "0.100001"), ("-2.5", "2.5"), ("1.0e-3", "1.0e-2")]:
            self.assertIsNotNone(compare_fixtures("f("+a+")", "f("+b+")"))


if __name__ == "__main__":
    unittest.main()
