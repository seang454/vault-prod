ui = true
disable_mlock = false

api_addr = "https://vault.seang.shop"
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