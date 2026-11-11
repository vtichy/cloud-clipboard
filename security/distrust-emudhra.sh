#!/bin/sh
set -eu

fingerprints='7dd78d5f4f13459a83dff9abbba62edbaf6f2d102bf257fd712f4d9f2746ed8d f2edaaff3d9b701fb4d14c9f285f8c0bad90fc3bcc1fa07d47f4718edaba34a5 d7a7a0fb5d7e2731d771e9484ebcdef71d5f0c3e0a2948782bc83ee0ea699ef4 86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b'
working_directory=$(mktemp -d)
trap 'rm -rf "$working_directory"' EXIT

if command -v update-ca-certificates >/dev/null; then
  sed -i \
    -e 's|^mozilla/Comodo_AAA_Services_root.crt|!&|' \
    -e 's|^mozilla/emSign_ECC_Root_CA_-_G3.crt|!&|' \
    /etc/ca-certificates.conf
  update-ca-certificates
elif command -v update-ca-trust >/dev/null; then
  awk -v directory="$working_directory" '
    /-----BEGIN CERTIFICATE-----/ { file = directory "/certificate-" ++number ".pem" }
    file { print > file }
    /-----END CERTIFICATE-----/ { close(file); file = "" }
  ' /etc/pki/tls/certs/ca-bundle.crt
  mkdir -p /etc/pki/ca-trust/source/blocklist
  for certificate in "$working_directory"/certificate-*.pem; do
    fingerprint=$(openssl x509 -in "$certificate" -noout -fingerprint -sha256 | cut -d= -f2 | tr -d ':' | tr 'A-F' 'a-f')
    case " $fingerprints " in
      *" $fingerprint "*) cp "$certificate" "/etc/pki/ca-trust/source/blocklist/emudhra-$fingerprint.pem" ;;
    esac
  done
  update-ca-trust
else
  echo 'No supported system trust-store manager found' >&2
  exit 1
fi

if command -v keytool >/dev/null; then
  keytool -J-Duser.language=en -list -v -cacerts -storepass changeit > "$working_directory/java-certificates"
  awk -v fingerprints="$fingerprints" '
    /^Alias name: / { alias = substr($0, 13) }
    /SHA256:/ {
      fingerprint = $0
      sub(/^.*SHA256: /, "", fingerprint)
      gsub(/:/, "", fingerprint)
      if (index(" " fingerprints " ", " " tolower(fingerprint) " ")) print alias
    }
  ' "$working_directory/java-certificates" > "$working_directory/java-aliases"
  while IFS= read -r alias; do
    keytool -delete -cacerts -storepass changeit -alias "$alias"
  done < "$working_directory/java-aliases"
fi
