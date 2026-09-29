"""Source topology checks before an offline tree bake can touch runtime assets."""
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from tree_leaf_components import components


class TreeComponentsTest(unittest.TestCase):
    def test_triangle_bridge_joins_groups_without_losing_separate_leaf(self):
        indices = [0, 1, 2, 3, 4, 5, 2, 3, 0, 6, 7, 8]
        result = {frozenset(group) for group in components(indices, 9)}
        self.assertEqual(result, {frozenset(range(6)), frozenset(range(6, 9))})

    def test_unreferenced_vertex_is_exposed_as_its_own_group(self):
        self.assertIn([3], components([0, 1, 2], 4))

    def test_invalid_triangles_fail_before_indexing(self):
        for indices, size in [([], 3), ([0, 1], 3), ([-1, 0, 1], 3),
                              ([0, 1, 3], 3), ([0, 1, 2], 0)]:
            with self.subTest(indices=indices, size=size), self.assertRaises(ValueError):
                components(indices, size)


if __name__ == '__main__':
    unittest.main()
