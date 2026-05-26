# Install Vault CLI on Linux

This guide installs the HashiCorp Vault CLI on Linux so you can run commands like:

```bash
vault login
vault kv put secret/kubeconfigs/benzcluster kubeconfig=@benzcluster-kubeconfig.yaml
vault kv get secret/kubeconfigs/benzcluster
```

## Ubuntu / Debian

Install required packages:

```bash
sudo apt update
sudo apt install -y gpg wget
```

Add the HashiCorp GPG key:

```bash
wget -O - https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
```

Add the HashiCorp repository:

```bash
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
```

Install Vault:

```bash
sudo apt update
sudo apt install -y vault
```

Check that Vault CLI is installed:

```bash
vault version
```

## Login to Your HTTPS Vault Server

Set your Vault HTTPS address:

```bash
export VAULT_ADDR=https://vault.seang.shop
```

Login:

```bash
vault login
```

Paste your Vault token when prompted.

## Store a Kubeconfig File in Vault

Example:

```bash
vault kv put secret/kubeconfigs/benzcluster kubeconfig=@benzcluster-kubeconfig.yaml
```

Multiple file as onece
```bash
vault kv put secret/kubeconfigs/benzcluster \
  kubeconfig=@benzcluster-kubeconfig.yaml \
  ca_cert=@ca.crt \
  token=@token.txt

```

Read it back:

```bash
vault kv get secret/kubeconfigs/benzcluster
```

## Make VAULT_ADDR Permanent

To avoid typing `export VAULT_ADDR=...` every time, add it to your shell profile:

```bash
echo 'export VAULT_ADDR=https://vault.seang.shop' >> ~/.bashrc
source ~/.bashrc
```

For Zsh:

```bash
echo 'export VAULT_ADDR=https://vault.seang.shop' >> ~/.zshrc
source ~/.zshrc
```

## If You Get `vault: command not found`

Check where Vault is installed:

```bash
which vault
```

If it returns nothing, Vault CLI is not installed or not in your `PATH`.

Install again with:

```bash
sudo apt update
sudo apt install -y vault
```

## Fix `NO_PUBKEY AA16FCBCA621E701`

If `sudo apt update` shows:

```text
NO_PUBKEY AA16FCBCA621E701
E: The repository 'https://apt.releases.hashicorp.com jammy InRelease' is not signed.
```

replace the local HashiCorp keyring and update again:

```bash
sudo rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg
wget -O - https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
sudo apt update
sudo apt install -y vault
```

If `gpg` asks before overwriting the file, type `y`.
