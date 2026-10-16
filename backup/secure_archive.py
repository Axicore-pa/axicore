"""Contenedor AXIBAK1: RSA-OAEP-SHA256 + AES-256-GCM, con cabecera autenticada."""
import json
import os
import struct
from pathlib import Path
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

MAGIC = b'AXIBAK1\n'
CHUNK = 1024 * 1024

def keypair(private_path, public_path):
    private_path, public_path = Path(private_path), Path(public_path)
    key = rsa.generate_private_key(public_exponent=65537, key_size=3072)
    # Nunca sobrescribir una llave de recuperación existente.
    with private_path.open('xb') as f:
        os.chmod(private_path, 0o600)
        f.write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
    with public_path.open('xb') as f:
        f.write(key.public_key().public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo))

def encrypt(source, destination, public_path):
    key = serialization.load_pem_public_key(Path(public_path).read_bytes())
    if not isinstance(key, rsa.RSAPublicKey) or key.key_size < 3072:
        raise ValueError('Se requiere una clave pública RSA de al menos 3072 bits')
    aes, nonce = os.urandom(32), os.urandom(12)
    wrapped = key.encrypt(aes, padding.OAEP(mgf=padding.MGF1(hashes.SHA256()), algorithm=hashes.SHA256(), label=None))
    header = json.dumps({'wrapped_key': wrapped.hex(), 'nonce': nonce.hex()}, separators=(',', ':')).encode()
    prefix = MAGIC + struct.pack('>I', len(header)) + header
    enc = Cipher(algorithms.AES(aes), modes.GCM(nonce)).encryptor()
    enc.authenticate_additional_data(prefix)
    with Path(source).open('rb') as src, Path(destination).open('xb') as dst:
        os.chmod(destination, 0o600)
        dst.write(prefix)
        while data := src.read(CHUNK):
            dst.write(enc.update(data))
        dst.write(enc.finalize())
        dst.write(enc.tag)

def decrypt(source, destination, private_path):
    source, destination = Path(source), Path(destination)
    if destination.exists():
        raise FileExistsError('El destino ya existe')
    key = serialization.load_pem_private_key(Path(private_path).read_bytes(), password=None)
    temp = destination.with_name(destination.name + '.' + os.urandom(8).hex() + '.partial')
    try:
        with source.open('rb') as src:
            magic, length = src.read(len(MAGIC)), src.read(4)
            if magic != MAGIC or len(length) != 4:
                raise ValueError('Formato inválido')
            size = struct.unpack('>I', length)[0]
            if size > 16384:
                raise ValueError('Cabecera inválida')
            raw = src.read(size)
            header = json.loads(raw)
            prefix = magic + length + raw
            aes = key.decrypt(bytes.fromhex(header['wrapped_key']), padding.OAEP(mgf=padding.MGF1(hashes.SHA256()), algorithm=hashes.SHA256(), label=None))
            remaining = source.stat().st_size - len(prefix) - 16
            if remaining < 0:
                raise ValueError('Archivo incompleto')
            src.seek(-16, 2)
            tag = src.read(16)
            src.seek(len(prefix))
            dec = Cipher(algorithms.AES(aes), modes.GCM(bytes.fromhex(header['nonce']), tag)).decryptor()
            dec.authenticate_additional_data(prefix)
            with temp.open('xb') as dst:
                os.chmod(temp, 0o600)
                while remaining:
                    data = src.read(min(CHUNK, remaining))
                    if not data:
                        raise ValueError('Archivo incompleto')
                    remaining -= len(data)
                    dst.write(dec.update(data))
                dst.write(dec.finalize())
        # Solo exponer el resultado después de verificar la autenticidad.
        temp.rename(destination)
    finally:
        temp.unlink(missing_ok=True)

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['keys', 'encrypt', 'decrypt'])
    parser.add_argument('source')
    parser.add_argument('destination')
    parser.add_argument('--key')
    args = parser.parse_args()
    if args.operation == 'keys':
        keypair(args.source, args.destination)
    elif args.operation == 'encrypt':
        encrypt(args.source, args.destination, args.key)
    else:
        decrypt(args.source, args.destination, args.key)
