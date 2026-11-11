import hashlib
from pathlib import Path
import re
import ssl
import subprocess
import sys
import tempfile

AFFECTED_ROOTS = {
    '7dd78d5f4f13459a83dff9abbba62edbaf6f2d102bf257fd712f4d9f2746ed8d',
    'f2edaaff3d9b701fb4d14c9f285f8c0bad90fc3bcc1fa07d47f4718edaba34a5',
    'd7a7a0fb5d7e2731d771e9484ebcdef71d5f0c3e0a2948782bc83ee0ea699ef4',
    '86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b',
}


def run(arguments):
    return subprocess.run(arguments, check=True, capture_output=True, text=True).stdout.strip()


def verify_bundle(bundle):
    certificates = re.findall(r'-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----', bundle, re.S)
    if not certificates:
        raise RuntimeError('No certificates found in trust bundle')
    fingerprints = {hashlib.sha256(ssl.PEM_cert_to_DER_cert(certificate)).hexdigest() for certificate in certificates}
    if fingerprints & AFFECTED_ROOTS:
        raise RuntimeError(f'Affected trust anchors remain: {sorted(fingerprints & AFFECTED_ROOTS)}')
    print(f'System trust: {len(certificates)} certificates; affected roots absent')


def main():
    image = sys.argv[1]
    runtime = sys.argv[2] if len(sys.argv) > 2 else 'system'
    container = run(['docker', 'create', '--network', 'none', '--entrypoint', '/bin/true', image])
    try:
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / 'ca-bundle.pem'
            for source in ['/etc/ssl/certs/ca-certificates.crt', '/etc/pki/tls/certs/ca-bundle.crt']:
                result = subprocess.run(['docker', 'cp', '-L', f'{container}:{source}', str(bundle)], capture_output=True)
                if result.returncode == 0:
                    verify_bundle(bundle.read_text())
                    break
            else:
                if runtime != 'node-only':
                    raise RuntimeError('System trust bundle not found')
    finally:
        run(['docker', 'rm', container])
    if runtime == 'java':
        listing = run(['docker', 'run', '--rm', '--network', 'none', '--entrypoint', 'keytool', image,
                       '-J-Duser.language=en', '-list', '-v', '-cacerts', '-storepass', 'changeit'])
        fingerprints = {value.replace(':', '').lower() for value in re.findall(r'SHA256: ([A-Fa-f0-9:]+)', listing)}
        if not fingerprints or fingerprints & AFFECTED_ROOTS:
            raise RuntimeError('Java trust store is missing or contains affected roots')
        print(f'Java trust: {len(fingerprints)} certificates; affected roots absent')
    elif runtime in {'node', 'node-only'}:
        script = "const {X509Certificate}=require('crypto'); console.log(JSON.stringify(require('tls').rootCertificates.map(c=>new X509Certificate(c).fingerprint256.replaceAll(':','').toLowerCase())))"
        import json
        fingerprints = set(json.loads(run(['docker', 'run', '--rm', '--network', 'none', '--entrypoint', 'node', image, '-e', script])))
        if not fingerprints or fingerprints & AFFECTED_ROOTS:
            raise RuntimeError('Node bundled trust contains affected roots')
        print(f'Node trust: {len(fingerprints)} certificates; affected roots absent')
    print(f'Passed: {image}')


if __name__ == '__main__':
    main()
