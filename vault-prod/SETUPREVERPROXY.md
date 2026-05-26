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

---

## 6. Login to Vault

```bash
docker exec -it vault-prod vault login
```

Paste your **root token** when prompted.

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