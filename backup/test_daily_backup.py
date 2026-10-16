import copy
import io
import json
import os
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import daily_backup as daily
from secure_archive import keypair, decrypt

class BackupTests(unittest.TestCase):
    def test_package_encryption_upload_verification_and_race_rejection(self):
        test_root = Path(__file__).resolve().parent / 'test-tmp'
        test_root.mkdir(exist_ok=True)
        real_tempdir = tempfile.TemporaryDirectory
        with real_tempdir(dir=test_root) as temp:
            root = Path(temp)
            self.assertTrue(root.resolve().is_relative_to(test_root.resolve()))
            (root/'backup').mkdir()
            keypair(root/'private.pem', root/'backup/recovery-public.pem')
            inventory = {'buckets':[{'id':'private'}], 'objects':[{'bucket':'private','name':'doc.pdf','id':'id1','metadata':{'size':3},'updated_at':'fixed'}]}
            uploaded = {}
            def fake_run(args, env=None):
                if args[0] in ('pg_dump','pg_dumpall'):
                    Path(args[args.index('--file')+1]).write_bytes(b'synthetic database')
                if args[0]=='psql': return b'[]'
                if args[0]=='git':
                    if 'bundle' in args: Path(args[args.index('create')+1]).write_bytes(b'bundle')
                    if 'archive' in args: return b'source'
                    if 'rev-parse' in args: return b'commit'
                if args[0]=='rclone':
                    self.assertIn('copyto', args)
                    uploaded['data']=Path(args[args.index('copyto')+1]).read_bytes()
                return b''
            def fake_api(url, headers, body=None):
                return {} if url.endswith('/config/auth') else []
            class Remote:
                def __init__(self, *a, **kw): self.stdout=io.BytesIO(uploaded['data'])
                def wait(self): return 0
            env={'AXICORE_DATABASE_URL':'postgresql://user:synthetic@localhost/database',
                 'AXICORE_SUPABASE_SERVICE_KEY':'synthetic-service', 'AXICORE_MANAGEMENT_TOKEN':'synthetic-token',
                 'AXICORE_RCLONE_CONFIG':'synthetic-config'}
            with patch.dict(os.environ,env,clear=True), patch.object(daily,'ROOT',root), \
                 patch.object(daily.shutil,'which',return_value='/mock/bin'), \
                 patch.object(daily,'run',side_effect=fake_run), patch.object(daily,'api',side_effect=fake_api), \
                 patch.object(daily,'http',return_value=(b'PDF','application/pdf')), \
                 patch.object(daily,'storage_inventory',side_effect=lambda *a:copy.deepcopy(inventory)), \
                 patch.object(daily.subprocess,'Popen',Remote), \
                 patch.object(daily.tempfile,'TemporaryDirectory',side_effect=lambda **kw:real_tempdir(dir=root,**kw)):
                daily.main()
                encrypted=root/'verified.axibak'
                encrypted.write_bytes(uploaded['data'])
                restored=root/'restored.tar.gz'
                decrypt(encrypted,restored,root/'private.pem')
                with tarfile.open(restored) as package:
                    manifest=json.load(package.extractfile('AXICORE/manifest.json'))
                    self.assertEqual(manifest['storage_objects'],1)
                    self.assertFalse(manifest['restore_tested'])
                    self.assertNotIn('private.pem',' '.join(package.getnames()))
                uploaded.clear()
                changed=copy.deepcopy(inventory)
                changed['objects'][0]['updated_at']='changed'
                with patch.object(daily,'storage_inventory',side_effect=[copy.deepcopy(inventory),changed]):
                    with self.assertRaisesRegex(RuntimeError,'Storage cambió'):
                        daily.main()
                self.assertEqual(uploaded,{})
                with patch.dict(os.environ,{},clear=True):
                    with self.assertRaisesRegex(RuntimeError,'AXICORE_DATABASE_URL'):
                        daily.main()

if __name__=='__main__':
    unittest.main()
