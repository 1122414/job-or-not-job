"""Verify build evidence changes with runtime content, not unrelated documents."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('build_manifest', Path(__file__).resolve().parents[1] / 'tools/build_manifest.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ManifestInputsTest(unittest.TestCase):
    def test_platform_renderer_overrides_base_without_changing_other_targets(self):
        config = 'renderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.macos="forward_plus"\n'
        self.assertEqual(module.configured_renderer(config, 'macos'), 'forward_plus')
        self.assertEqual(module.configured_renderer(config, 'web'), 'gl_compatibility')

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        for folder in ('assets', 'scripts', 'scenes', 'docs', 'build'):
            (self.root / folder).mkdir()
        (self.root / 'project.godot').write_text('version=1')
        (self.root / 'export_presets.cfg').write_text('preset=1')
        (self.root / 'scripts/game.gd').write_text('extends Node')

    def test_runtime_edit_changes_identity_inputs(self):
        before = module.runtime_inputs(self.root)
        (self.root / 'scripts/game.gd').write_text('extends Node3D')
        self.assertNotEqual(before, module.runtime_inputs(self.root))

    def test_untracked_asset_is_identified(self):
        (self.root / 'assets/办公室.bin').write_bytes(b'asset')
        self.assertEqual(module.runtime_inputs(self.root)['assets/办公室.bin'], hashlib.sha256(b'asset').hexdigest())

    def test_documents_and_previous_builds_are_not_runtime_inputs(self):
        before = module.runtime_inputs(self.root)
        (self.root / 'docs/plan.md').write_text('changed')
        (self.root / 'build/old.pck').write_bytes(b'old')
        (self.root / 'assets/.DS_Store').write_bytes(b'finder')
        self.assertEqual(before, module.runtime_inputs(self.root))

    def test_deleted_runtime_file_changes_manifest(self):
        before = module.runtime_inputs(self.root)
        (self.root / 'scripts/game.gd').unlink()
        self.assertNotEqual(before, module.runtime_inputs(self.root))


if __name__ == '__main__':
    unittest.main()
