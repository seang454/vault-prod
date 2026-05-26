#!/usr/bin/env sh

set -eu

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <vault-https-url> <vault-secret-path> <file-path> [vault-property-name]" >&2
  echo "Example: $0 https://vault.seang.shop secret/kubeconfigs/benzcluster benzcluster-kubeconfig.yaml kubeconfig" >&2
  exit 1
fi

VAULT_ADDR="$1"
SECRET_PATH="$2"
FILE_PATH="$3"
PROPERTY_NAME="${4:-kubeconfig}"

if [ ! -f "$FILE_PATH" ]; then
  echo "Error: file not found: $FILE_PATH" >&2
  exit 1
fi

if ! command -v vault >/dev/null 2>&1; then
  echo "Error: vault CLI is not installed or not in PATH." >&2
  exit 1
fi

export VAULT_ADDR

vault kv put "$SECRET_PATH" "$PROPERTY_NAME=@$FILE_PATH"

echo "Stored file in Vault."
echo "Vault address: $VAULT_ADDR"
echo "Secret path: $SECRET_PATH"
echo "Property: $PROPERTY_NAME"
