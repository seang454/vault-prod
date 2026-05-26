# HashiCorp Vault Setup Guide

## 1. Start Vault with Docker Compose

```bash
docker compose up -d
docker logs -f vault-prod
```

---

## 2. Configure Nginx Reverse Proxy

Create the Nginx site config:

```bash
sudo nano /etc/nginx/sites-available/vault.seang.shop
```

Paste the following:

```nginx
server {
    listen 80;
    server_name vault.seang.shop;

    location / {
        proxy_pass http://127.0.0.1:8200;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
    }
}
```

Enable the site and reload Nginx:

```bash
sudo ln -s /etc/nginx/sites-available/vault.seang.shop /etc/nginx/sites-enabled/vault.seang.shop
sudo nginx -t
sudo systemctl reload nginx
```

Test the proxy:

```bash
curl -I -H "Host: vault.seang.shop" http://127.0.0.1
```

---

## 3. Enable HTTPS with Certbot

```bash
sudo certbot --nginx -d vault.seang.shop
```

Verify HTTPS:

```bash
curl -I https://vault.seang.shop
```

---

## 4. Initialize Vault

```bash
docker exec -it vault-prod vault operator init
```

> **Important:** Save the following securely:
> - Unseal Keys (5 keys generated)
> - Initial Root Token

---

## 5. Unseal Vault

Run the following command **3 times**, each time using a different unseal key:

```bash
docker exec -it vault-prod vault operator unseal
```

Check the status after unsealing:

```bash
docker exec -it vault-prod vault status
```
it will work
`
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            5
Threshold               3
Version                 1.20.4
Build Date              2025-09-23T13:22:38Z
Storage Type            raft
Cluster Name            vault-cluster-810c61df
Cluster ID              72b7d9b5-0393-ad43-fe6d-ff8c2a5fb1ac
Removed From Cluster    false
HA Enabled              true
HA Cluster              https://127.0.0.1:8201
HA Mode                 active
Active Since            2026-05-26T04:02:43.767818655Z
Raft Committed Index    37
Raft Applied Index      37

`

---

## 6. Login to Vault

### Option A: Login from inside the Vault container

```bash
docker exec -it vault-prod vault login
```

Paste your **root token** when prompted.

### Option B: Login from your machine using HTTPS

Use this when your Vault is reachable through the domain:

```bash
export VAULT_ADDR=https://vault.seang.shop
vault login
```

`VAULT_ADDR` tells the Vault CLI which HTTPS Vault server to use. After setting it, every `vault` command will use `https://vault.seang.shop` by default.

For Windows PowerShell:

```powershell
$env:VAULT_ADDR = "https://vault.seang.shop"
vault login
```

---

## 7. Enable KV Secret Engine

```bash
docker exec -it vault-prod vault secrets enable -path=secret kv-v2
```

---

## 8. Store and Read a Test Secret

Write a secret:

```bash
docker exec -it vault-prod vault kv put secret/test hello=world
```

Read it back:

```bash
docker exec -it vault-prod vault kv get secret/test
```

---

## 9. Store a Kubeconfig File in Vault over HTTPS

Set the Vault HTTPS address:

```bash
export VAULT_ADDR=https://vault.seang.shop
```

Login:

```bash
vault login
```

Store the whole kubeconfig file as one value:

```bash
vault kv put secret/kubeconfigs/benzcluster kubeconfig=@benzcluster-kubeconfig.yaml
```

Read it back:

```bash
vault kv get secret/kubeconfigs/benzcluster
```

The stored value can be used by External Secrets with:

```yaml
remoteRef:
  key: secret/kubeconfigs/benzcluster
  property: kubeconfig
```
