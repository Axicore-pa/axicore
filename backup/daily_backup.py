"""Ejecutar en Linux confiable; nunca desde el navegador del residente.
No registra datos, credenciales ni respuestas de API en stdout/stderr.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from secure_archive import encrypt

ROOT = Path(__file__).resolve().parents[1]
REF = 'qfgyftsnwznsqizriggr'
FOLDER = '1jMkR2PPQkpDlFVhqbTE1F6MjdvE1At_N'

def required(name):
    value = os.environ.get(name)
    if not value:
        raise RuntimeError('Falta configurar ' + name)
    return value

def run(args, env=None):
    result = subprocess.run(args, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if result.returncode:
        # Los errores de herramientas externas pueden contener secretos.
        raise RuntimeError('Falló ' + Path(args[0]).name + '; revisar la configuración privada del ejecutor')
    return result.stdout

def http(url, headers, body=None):
    payload = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=payload, headers={**headers, **({'Content-Type': 'application/json'} if payload is not None else {})})
    with urllib.request.urlopen(req, timeout=120) as res:
        return res.read(), res.headers.get('Content-Type', '')

def api(url, headers, body=None):
    return json.loads(http(url, headers, body)[0])

def save_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf8')

def sha(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

def storage_inventory(base, headers):
    buckets = api(base + '/bucket', headers)
    objects = []
    for bucket in buckets:
        pending = ['']
        while pending:
            prefix, offset = pending.pop(), 0
            while True:
                page = api(base + '/object/list/' + urllib.parse.quote(bucket['id'], safe=''), headers,
                           {'prefix': prefix, 'limit': 1000, 'offset': offset, 'sortBy': {'column': 'name', 'order': 'asc'}})
                if not isinstance(page, list):
                    raise RuntimeError('Inventario de Storage inválido')
                for obj in page:
                    name = (prefix + '/' if prefix else '') + obj['name']
                    if obj.get('id') is None:
                        pending.append(name)
                    else:
                        objects.append({'bucket': bucket['id'], 'name': name, 'id': obj['id'],
                                        'updated_at': obj.get('updated_at'), 'metadata': obj.get('metadata')})
                if len(page) < 1000:
                    break
                offset += len(page)
    return {'buckets': buckets, 'objects': sorted(objects, key=lambda x: (x['bucket'], x['name']))}

def main():
    os.umask(0o077)
    db_url = required('AXICORE_DATABASE_URL')
    service_key = required('AXICORE_SUPABASE_SERVICE_KEY')
    management_key = required('AXICORE_MANAGEMENT_TOKEN')
    rclone_config = required('AXICORE_RCLONE_CONFIG')
    for command in ['pg_dump', 'pg_dumpall', 'pg_restore', 'psql', 'git', 'rclone']:
        if not shutil.which(command):
            raise RuntimeError('Falta instalar ' + command)
    public_key = ROOT / 'backup/recovery-public.pem'
    if not public_key.is_file():
        raise RuntimeError('Falta la clave pública de recuperación')
    parts = urllib.parse.urlsplit(db_url)
    if parts.scheme not in ('postgres', 'postgresql') or not parts.hostname or not parts.username or not parts.password:
        raise RuntimeError('La conexión PostgreSQL está incompleta')
    pg_env = {k: v for k, v in os.environ.items() if not k.startswith('PG')}
    pg_env.update(PGHOST=parts.hostname, PGPORT=str(parts.port or 5432), PGDATABASE=urllib.parse.unquote(parts.path.lstrip('/')),
                  PGUSER=urllib.parse.unquote(parts.username), PGPASSWORD=urllib.parse.unquote(parts.password), PGSSLMODE='require', PGCONNECT_TIMEOUT='30')
    base = f'https://{REF}.supabase.co/storage/v1'
    headers = {'apikey': service_key, 'Authorization': 'Bearer ' + service_key}
    admin_headers = {'Authorization': 'Bearer ' + management_key}
    admin_url = f'https://api.supabase.com/v1/projects/{REF}'
    started = datetime.now(timezone.utc).isoformat()
    with tempfile.TemporaryDirectory(prefix='axicore-backup-') as temp:
        temp = Path(temp)
        package = temp / 'package'
        package.mkdir()
        initial = storage_inventory(base, headers)
        # pg_dump utiliza un snapshot transaccional para esquema y datos juntos.
        run(['pg_dump', '--format=custom', '--no-owner', '--file', str(package / 'database.dump')], pg_env)
        run(['pg_restore', '--list', str(package / 'database.dump')])
        run(['pg_dumpall', '--roles-only', '--no-role-passwords', '--file', str(package / 'roles.sql')], pg_env)
        cron = run(['psql', '-X', '-A', '-t', '-v', 'ON_ERROR_STOP=1', '-c', "SELECT coalesce(jsonb_agg(to_jsonb(j)), '[]'::jsonb) FROM cron.job j"], pg_env)
        (package / 'cron.json').write_bytes(cron)
        files = package / 'storage'
        files.mkdir()
        for obj in initial['objects']:
            file_id = hashlib.sha256((obj['bucket'] + '/' + obj['name']).encode()).hexdigest()
            url = base + '/object/authenticated/' + urllib.parse.quote(obj['bucket'], safe='') + '/' + urllib.parse.quote(obj['name'], safe='/')
            content, _ = http(url, headers)
            (files / file_id).write_bytes(content)
            obj['backup_file'] = 'storage/' + file_id
            obj['sha256'] = sha(files / file_id)
            expected_size = (obj.get('metadata') or {}).get('size')
            if expected_size is not None and int(expected_size) != len(content):
                raise RuntimeError('Tamaño de objeto inconsistente')
        # No aceptar una copia si cambió el inventario de archivos durante el proceso.
        final = storage_inventory(base, headers)
        comparable = {'buckets': initial['buckets'], 'objects': [{k: v for k, v in x.items() if k not in ('backup_file', 'sha256')} for x in initial['objects']]}
        if final != comparable:
            raise RuntimeError('Storage cambió durante la copia; reintentar en una ventana estable')
        save_json(package / 'storage.json', initial)
        functions = api(admin_url + '/functions', admin_headers)
        save_json(package / 'functions.json', functions)
        function_dir = package / 'functions'
        function_dir.mkdir()
        for function in functions:
            slug = function['slug']
            if not re.fullmatch(r'[A-Za-z0-9_-]+', slug):
                raise RuntimeError('Nombre de función inválido')
            body, content_type = http(admin_url + '/functions/' + slug + '/body', admin_headers)
            if not body:
                raise RuntimeError('Función sin contenido exportado')
            (function_dir / (slug + '.body')).write_bytes(body)
            (function_dir / (slug + '.content-type')).write_text(content_type)
        if functions != api(admin_url + '/functions', admin_headers):
            raise RuntimeError('Cambió una función durante la copia')
        save_json(package / 'auth-config.json', api(admin_url + '/config/auth', admin_headers))
        # Configuración secreta NO recuperable por API: mantener custodia separada.
        save_json(package / 'secret-inventory.json', api(admin_url + '/secrets', admin_headers))
        run(['git', '-C', str(ROOT), 'bundle', 'create', str(package / 'repository.bundle'), '--all'])
        with (package / 'source.tar').open('wb') as f:
            f.write(run(['git', '-C', str(ROOT), 'archive', '--format=tar', 'HEAD']))
        commit = run(['git', '-C', str(ROOT), 'rev-parse', 'HEAD']).decode().strip()
        manifest = {'format': 1, 'started_utc': started, 'completed_utc': datetime.now(timezone.utc).isoformat(),
                    'project': REF, 'commit': commit, 'storage_objects': len(initial['objects']),
                    'restore_tested': False, 'requires_separate_secret_custody': True,
                    'files': {str(p.relative_to(package)): {'bytes': p.stat().st_size, 'sha256': sha(p)} for p in package.rglob('*') if p.is_file()}}
        save_json(package / 'manifest.json', manifest)
        archive = temp / 'snapshot.tar.gz'
        with tarfile.open(archive, 'w:gz') as tar:
            tar.add(package, arcname='AXICORE')
        filename = 'AXICORE-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + os.urandom(4).hex() + '.axibak'
        encrypted = temp / filename
        encrypt(archive, encrypted, public_key)
        config = temp / 'rclone.conf'
        config.write_text(rclone_config, encoding='utf8')
        common = ['rclone', '--config', str(config), '--drive-root-folder-id', FOLDER]
        run(common + ['copyto', str(encrypted), 'axicore:' + filename])
        # La subida solo se declara correcta tras volver a leer sus bytes cifrados.
        verify = subprocess.Popen(common + ['cat', 'axicore:' + filename], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        remote_hash = hashlib.file_digest(verify.stdout, 'sha256').hexdigest()
        verify.stdout.close()
        if verify.wait() or remote_hash != sha(encrypted):
            raise RuntimeError('No se confirmó la integridad de la copia remota')
        print('Copia cifrada subida y verificada: ' + filename)
        print('Restauración integral pendiente de simulacro; no se borró ninguna copia anterior.')

if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Nunca imprimir respuestas de red, credenciales ni traceback de datos.
        message = str(error) if isinstance(error, RuntimeError) else type(error).__name__
        print('RESPALDO FALLIDO: ' + message, file=sys.stderr)
        sys.exit(1)
