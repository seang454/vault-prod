# Vault Kubeconfig ExternalSecret Helm Chart

This chart reads kubeconfig file values from HashiCorp Vault and creates a Kubernetes Secret using External Secrets Operator.

Vault data expected:

```bash
vault kv put secret/kubeconfigs/benzcluster \
  k8s-cluster1=@config.yaml \
  k8s-cluster2=@config-cluster2.yaml
```

Because the `SecretStore` uses:

```yaml
path: secret
version: v2
```

the `ExternalSecret` remote key is:

```text
kubeconfigs/benzcluster
```

not:

```text
secret/kubeconfigs/benzcluster
```

## Prerequisite

External Secrets Operator must already be installed in the Kubernetes cluster.

## Create the Vault Token Secret

Create this in the same namespace where you install the chart:

```bash
kubectl create namespace backend

kubectl create secret generic vault-token \
  --from-literal=token='<vault-token>' \
  -n backend
```

Use a limited Vault token in production. Do not use the root token for normal application sync.

## Install the Chart

From this repository root:

```bash
helm upgrade --install vault-kubeconfigs ./charts/vault-kubeconfig-external-secret \
  -n backend
```

## Verify

```bash
kubectl get secretstore vault-secret-store -n backend
kubectl get externalsecret benzcluster-kubeconfigs -n backend
kubectl get secret benzcluster-kubeconfigs -n backend
```

The generated Kubernetes Secret will contain:

```text
config.yaml
config-cluster2.yaml
```

## Install by Passing the Token with Helm

This is convenient for testing but not recommended for GitOps history:

```bash
helm upgrade --install vault-kubeconfigs ./charts/vault-kubeconfig-external-secret \
  -n backend \
  --create-namespace \
  --set vault.auth.createTokenSecret=true \
  --set-string vault.auth.token='<vault-token>'
```

vault-token Secret
  -> lets External Secrets Operator connect to Vault

SecretStore
  -> tells ESO where Vault is

ExternalSecret
  -> tells ESO what to read from Vault

benzcluster-kubeconfigs Secret
  -> final Kubernetes Secret created from Vault data