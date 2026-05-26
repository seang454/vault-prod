# HashiCorp Vault — Configuration Reference

This document explains the `vault.hcl` configuration file used to run a single-node production Vault instance with Nginx as a TLS reverse proxy and Raft as the storage backend.

---

## Configuration File

```hcl
ui = true
disable_mlock = false

api_addr     = "https://vault.seang.shop"
cluster_addr = "http://127.0.0.1:8201"

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = true
}

storage "raft" {
  path    = "/vault/data"
  node_id = "vault-1"
}
```

---

## Configuration Breakdown

### UI

```hcl
ui = true
```

Enables the built-in Vault Web UI, accessible at `https://vault.seang.shop/ui`.
Set to `false` if you want CLI/API-only access.

---

### Memory Lock

```hcl
disable_mlock = false
```

Keeps memory locking **enabled**. This prevents the OS from swapping Vault's in-memory secrets (tokens, keys, etc.) to disk, which is important for production security.

> **Note:** On some systems (e.g., Docker without `IPC_LOCK` capability), you may need to set this to `true` or grant the capability in your `docker-compose.yml`.

---

### Address Settings

```hcl
api_addr     = "https://vault.seang.shop"
cluster_addr = "http://127.0.0.1:8201"
```

| Setting        | Description                                                                 |
|----------------|-----------------------------------------------------------------------------|
| `api_addr`     | The public-facing URL clients use to reach the Vault API                   |
| `cluster_addr` | Internal address used for Raft peer-to-peer communication between nodes     |

---

### Listener

```hcl
listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = true
}
```

| Option            | Description                                                                 |
|-------------------|-----------------------------------------------------------------------------|
| `address`         | Vault listens on all interfaces on port `8200` for API traffic             |
| `cluster_address` | Port `8201` is used for internal Raft cluster communication                |
| `tls_disable`     | TLS is disabled at the Vault level — handled upstream by **Nginx**         |

---

### Storage (Raft)

```hcl
storage "raft" {
  path    = "/vault/data"
  node_id = "vault-1"
}
```

Uses Vault's built-in **Integrated Raft Storage** — no external database required.

| Option    | Description                                               |
|-----------|-----------------------------------------------------------|
| `path`    | Directory where Vault persists all encrypted data on disk |
| `node_id` | Unique identifier for this node in a Raft cluster         |

---

## Architecture Overview

```
Client (HTTPS :443)
        │
        ▼
┌──────────────┐
│    Nginx     │  ← TLS termination (Let's Encrypt)
└──────┬───────┘
       │ HTTP
       ▼
┌──────────────┐
│  Vault :8200 │  ← API & Web UI
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Raft Store  │  ← /vault/data (encrypted at rest)
└──────────────┘
```

- **Nginx** handles all HTTPS/TLS so Vault can run plain HTTP internally
- **Raft** provides durable, encrypted storage without any external dependency
- **Port 8201** is reserved for Raft cluster traffic (used if you expand to multi-node)

---

## Notes

- This is a **single-node** setup. To expand to a multi-node HA cluster, add additional `storage "raft"` peers and update `cluster_addr` accordingly.
- Vault data at `/vault/data` is encrypted at rest by Vault's own encryption — but the directory should still be protected at the OS/filesystem level.
- After any restart, Vault will be **sealed** and must be unsealed using 3 of the 5 unseal keys before it can serve requests.