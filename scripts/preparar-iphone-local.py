#!/usr/bin/env python3
"""Generar una conexión TLS privada para Emulator Suite, sin instalar certificados del sistema."""
import argparse, base64, ipaddress, json, os, subprocess
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--host', required=True, help='IPv4 privada del servidor de Emulator Suite')
p.add_argument('--salida', default='.secrets/iphone-local')
for nombre, defecto in [('auth',9099),('firestore',8080),('functions',5001),('storage',9199),('tls',5443)]:
    p.add_argument(f'--{nombre}-port', type=int, default=defecto)
a = p.parse_args()
ip = ipaddress.ip_address(a.host)
redes = [ipaddress.ip_network(r) for r in ['10.0.0.0/8','172.16.0.0/12','192.168.0.0/16']]
if ip.version != 4 or not any(ip in r for r in redes):
    p.error('Usa una dirección IPv4 de la red privada.')
if any(not 0 < getattr(a, f'{n}_port') < 65536 for n in ['auth','firestore','functions','storage','tls']):
    p.error('Revisa los puertos.')
salida = Path(a.salida)
salida.mkdir(parents=True, exist_ok=True, mode=0o700)
salida.chmod(0o700)
if (salida/'servidor.key').exists() or (salida/'servidor.pem').exists():
    p.error('Esa carpeta ya contiene un certificado. Usa otra salida para conservarlo.')
os.umask(0o077)
config = salida/'config.cnf'
config.write_text(f'''[req]
distinguished_name=nombre
x509_extensions=extensiones
prompt=no
[nombre]
CN=FinanceBro local
[extensiones]
basicConstraints=critical,CA:TRUE
keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign
extendedKeyUsage=serverAuth
subjectAltName=IP:{a.host}
''')
subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-sha256','-days','7','-config',str(config),'-keyout',str(salida/'servidor.key'),'-out',str(salida/'servidor.pem')],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
d = {'USE_EMULATORS':'true','EMULATOR_HOST':a.host,'EMULATOR_TLS_CERT':base64.b64encode((salida/'servidor.pem').read_bytes()).decode(),'FUNCTIONS_TLS_PORT':str(a.tls_port),'AUTH_PORT':str(a.auth_port),'FIRESTORE_PORT':str(a.firestore_port),'FUNCTIONS_PORT':str(a.functions_port),'STORAGE_PORT':str(a.storage_port)}
(salida/'definiciones.json').write_text(json.dumps(d,indent=2)+'\n')
for archivo in salida.iterdir():
    if archivo.is_file(): archivo.chmod(0o600)
print('Certificado y definiciones locales preparados; vigencia de 7 días.')
print('Conserva la clave en el servidor. El certificado público se incluye en la app mediante definiciones.json.')
