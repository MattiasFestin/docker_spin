#!/bin/bash
set -x -o pipefail

rm -rf ./data
mkdir -p log

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=devroot

IP_ADDRESS=$(ip addr show dev eth0 | grep inet | cut -d: -f3 | awk '{print $2}' | rev | cut -c4- | rev)

echo "Starting consul..."
consul agent -dev \
  -config-file ./etc/consul.hcl \
  -bootstrap-expect 1 \
  -client '0.0.0.0' \
  -bind "${IP_ADDRESS}" \
  &>log/consul.log &

echo "Waiting for consul..."
while ! consul members &>/dev/null; do
  sleep 2
done

echo "Starting vault..."
vault server -dev \
  -dev-root-token-id "$VAULT_TOKEN" \
  -config ./etc/vault.hcl \
  &>log/vault.log &

echo "Waiting for vault..."
while ! grep -q 'Unseal Key' <log/vault.log; do
  sleep 2
done

echo "Storing unseal token in ./data/vault/unseal"
if [ ! -f data/vault/unseal ]; then
  awk '/^Root Token:/ { print $NF }' <log/vault.log >data/vault/token
  awk '/^Unseal Key:/ { print $NF }' <log/vault.log >data/vault/unseal
fi

echo "Starting nomad..."
nomad agent -dev \
  -config ./etc/nomad.hcl \
  -data-dir "${PWD}/data/nomad" \
  -network-interface $(ip -o -4 route show to default | awk '{print $5}') \
  -consul-address "${IP_ADDRESS}:8500" \
  &>log/nomad.log &

echo "Waiting for nomad..."
while ! nomad server members 2>/dev/null | grep -q alive; do
  sleep 2
done

echo "Starting traefik job..."
nomad run job/traefik.nomad

echo "Starting bindle job..."
nomad run job/bindle.nomad

echo "Starting hippo job..."
nomad run job/hippo.nomad

echo
echo "Dashboards"
echo "----------"
echo "Consul:  http://localhost:8500"
echo "Nomad:   http://localhost:4646"
echo "Vault:   http://localhost:8200"
echo "Traefik: http://localhost:8081"
echo
echo "Logs are stored in ./log"
echo
echo "Export these into your shell"
echo
echo "    export CONSUL_HTTP_ADDR=http://localhost:8500"
echo "    export NOMAD_ADDR=http://localhost:4646"
echo "    export VAULT_ADDR=${VAULT_ADDR}"
echo "    export VAULT_TOKEN=$(<data/vault/token)"
echo "    export VAULT_UNSEAL=$(<data/vault/unseal)"
echo "    export BINDLE_URL=http://bindle.localhost/v1"
echo "    export HIPPO_URL=http://hippo.localhost"
echo
echo "Ctrl+C to exit."
echo

wait
