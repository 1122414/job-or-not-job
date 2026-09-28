import hashlib
from pathlib import Path
import tempfile
import unittest

from tools.fetch_open_assets import checked_download, safe_path, validate_origin, AssetRedirect
from urllib.request import Request


class AssetImportSafetyTest(unittest.TestCase):
    def test_path_traversal_and_symlink_escape_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp) / 'assets'
            base.mkdir()
            (base / 'escape').symlink_to(Path(tmp), target_is_directory=True)
            for name in ('../file.jpg', '/file.jpg', 'textures\\file.jpg', 'escape/file.jpg'):
                with self.subTest(name=name), self.assertRaises(ValueError):
                    safe_path(base, name)
            self.assertEqual(safe_path(base, 'textures/a.jpg'), base / 'textures/a.jpg')

    def test_only_official_https_origin_and_redirects_allowed(self):
        for url in ('http://dl.polyhaven.org/a', 'https://other.invalid/a', 'https://user@dl.polyhaven.org/a'):
            with self.subTest(url=url), self.assertRaises(ValueError):
                validate_origin(url, 'dl.polyhaven.org')
        with self.assertRaises(ValueError):
            AssetRedirect().redirect_request(Request('https://dl.polyhaven.org/a'), None, 302, '', {}, 'https://other.invalid/a')

    def test_existing_modified_asset_is_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'a.jpg'
            path.write_bytes(b'artist edit')
            with self.assertRaises(ValueError):
                checked_download(path, {'size': 5, 'md5': hashlib.md5(b'asset').hexdigest(), 'url': 'https://dl.polyhaven.org/a'})
            self.assertEqual(path.read_bytes(), b'artist edit')

    def test_valid_existing_asset_needs_no_network(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'a.jpg'
            path.write_bytes(b'asset')
            record = checked_download(path, {'size': 5, 'md5': hashlib.md5(b'asset').hexdigest(), 'url': 'https://dl.polyhaven.org/a'})
            self.assertEqual(record['sha256'], hashlib.sha256(b'asset').hexdigest())


if __name__ == '__main__':
    unittest.main()
