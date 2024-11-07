#!/bin/bash

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

create_cert_ext() {
  # create the CA extension file
  cat <<EOF > "${SCRIPT_DIR}"/certs/test.ext
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName=@alt_names

[alt_names]
DNS.1=${HOSTNAME}
DNS.2=localhost
EOF
}

create_certs() {
  if [ ! -d "${SCRIPT_DIR}"/certs ] || [ -z "$(ls -A "${SCRIPT_DIR}"/certs)" ]; then
    # create the CA extension file
    create_cert_ext
    pushd "${SCRIPT_DIR}"/certs || exit
    # generate the local CA key
    openssl genrsa -out ./myCA.key 2048
    # generate the local CA cert
    openssl req -x509 -new -nodes -key ./myCA.key -sha384 -days 999 -out ./myCA.pem -subj "/C=XX/ST=Confusion/L=Somewhere/O=example/CN=CertificateAuthority"
    # create certificate signing request
    openssl req -newkey rsa:4096 -nodes -sha384 -keyout ./test.key -out ./test.csr -subj "/C=XX/ST=Confusion/L=Somewhere/OU=first/OU=a002/OU=third/OU=b004/O=example/CN=$(hostname)"
    # process the signing request and sign with the fake CA
    openssl x509 -req -in ./test.csr -CA ./myCA.pem -CAkey ./myCA.key -CAcreateserial -out ./test.crt -days 999 -sha384 -extfile ./test.ext
    # create PKCS#12 file
    openssl pkcs12 -export -out ./test.p12 -inkey ./test.key -in ./test.crt -certfile ./myCA.pem -passout pass:test
    # return to previous dir
    popd || exit
  else
    echo "Certs already present in "${SCRIPT_DIR}"/certs"
  fi
}

stop() {
  docker compose down
}

start() {
  create_certs
  docker compose up -d
}

TEMP=$(getopt -o st --long start,stop -- "$@")
eval set -- "${TEMP}"
case "$1" in
  -s|--start)
    target=start
    ;;
  -t|--stop)
    target=stop
    ;;
  *) echo "Invalid option selected!"
    exit 1
    ;;
esac

eval "${target}"