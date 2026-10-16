import os
import tempfile
import unittest
from pathlib import Path
from secure_archive import keypair, encrypt, decrypt

class ArchiveTests(unittest.TestCase):
    def test_roundtrip_tampering_and_wrong_key(self):
        test_root = Path(__file__).resolve().parent / 'test-tmp'
        test_root.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=test_root) as temp:
            root = Path(temp)
            self.assertTrue(root.resolve().is_relative_to(test_root.resolve()))
            private, public = root/'private.pem', root/'public.pem'
            keypair(private, public)
            keypair(root/'wrong-private.pem', root/'wrong-public.pem')
            for i, content in enumerate([b'', b'AXICORE\n', os.urandom(2100000)]):
                source, encrypted, restored = root/f'source{i}', root/f'copy{i}', root/f'restored{i}'
                source.write_bytes(content)
                encrypt(source, encrypted, public)
                decrypt(encrypted, restored, private)
                self.assertEqual(content, restored.read_bytes())
                for position in [20, len(encrypted.read_bytes())//2, -1]:
                    corrupt = bytearray(encrypted.read_bytes())
                    corrupt[position] ^= 1
                    bad = root/'bad'
                    bad.write_bytes(corrupt)
                    with self.assertRaises(Exception):
                        decrypt(bad, root/'must-not-exist', private)
                    self.assertFalse((root/'must-not-exist').exists())
                with self.assertRaises(Exception):
                    decrypt(encrypted, root/'wrong-result', root/'wrong-private.pem')
                self.assertFalse((root/'wrong-result').exists())
            with self.assertRaises(FileExistsError):
                keypair(private, public)

if __name__ == '__main__':
    unittest.main()
