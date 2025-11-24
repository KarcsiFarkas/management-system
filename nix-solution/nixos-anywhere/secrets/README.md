# Secrets Management with sops-nix

This directory contains encrypted secrets managed by [sops-nix](https://github.com/Mic92/sops-nix).

## Initial Setup

### 1. Install Required Tools

```bash
# On NixOS
nix-shell -p sops age

# Or enter the development shell
nix develop
```

### 2. Generate an Age Key

```bash
# Create directory for age keys
mkdir -p ~/.config/sops/age

# Generate a new age key
age-keygen -o ~/.config/sops/age/keys.txt

# View your public key
cat ~/.config/sops/age/keys.txt | grep "public key:"
```

The public key will look like: `age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p`

### 3. Configure sops

Edit `.sops.yaml` and replace the placeholder age key with your actual public key:

```yaml
creation_rules:
  - path_regex: secrets\.yaml$
    key_groups:
      - age:
          - age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p  # Your public key here
```

### 4. Create and Encrypt Secrets

```bash
# Copy the example file
cp secrets.yaml.example secrets.yaml

# Edit the file and replace all REPLACE_WITH_ACTUAL_* values
# Use strong, randomly generated secrets

# Encrypt the file
sops -e -i secrets.yaml
```

## Working with Encrypted Secrets

### Edit Encrypted Secrets

```bash
# sops will decrypt, open in editor, and re-encrypt on save
sops secrets.yaml
```

### View Encrypted Secrets

```bash
# Decrypt and display (does not modify file)
sops -d secrets.yaml
```

### Add New Secrets

```bash
# Edit the file
sops secrets.yaml

# Add new secret in the appropriate section
# Save and exit - sops will handle encryption
```

## Generating Secure Secrets

### Random Passwords

```bash
# 32-character alphanumeric password
openssl rand -base64 32

# 64-character password
openssl rand -base64 64

# Hex-encoded secret (for API keys)
openssl rand -hex 32
```

### UUIDs

```bash
# For instance IDs, unique identifiers
uuidgen
```

### htpasswd (for HTTP Basic Auth)

```bash
# Generate password hash for Traefik dashboard
htpasswd -nb admin your-password
```

### SSH Keys

```bash
# Generate ED25519 key pair
ssh-keygen -t ed25519 -C "deployment@server" -f ~/.ssh/id_ed25519_deployment
```

## Deployment with nixos-anywhere

When deploying with nixos-anywhere, you need to provide the age private key to the target system.

### Option 1: During Initial Deployment

Create a deployment key file:

```bash
# Extract your private key
grep -v "public key" ~/.config/sops/age/keys.txt > /tmp/age-key.txt

# Deploy with the key
# The key will be placed at /var/lib/sops-nix/key.txt on the target system
```

### Option 2: Manual Key Placement

After initial deployment, manually copy the key to the target:

```bash
# Copy age key to target server
scp ~/.config/sops/age/keys.txt root@target-ip:/var/lib/sops-nix/key.txt

# Set proper permissions
ssh root@target-ip "chmod 600 /var/lib/sops-nix/key.txt"
```

## Key Rotation

### Rotating the Age Key

1. Generate a new age key
2. Add the new public key to `.sops.yaml`
3. Re-encrypt all secrets with the new key:

```bash
# Re-encrypt with new key
sops updatekeys secrets.yaml
```

4. Remove the old key from `.sops.yaml`

### Rotating Secrets

1. Generate new secret values
2. Update secrets.yaml:

```bash
sops secrets.yaml
```

3. Redeploy the affected systems:

```bash
# Update the system
nixos-rebuild switch --flake .#hostname --target-host root@target-ip
```

## Multi-User Setup

To allow multiple team members to manage secrets:

1. Each team member generates their own age key
2. Collect all public keys
3. Update `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: secrets\.yaml$
    key_groups:
      - age:
          - age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p  # Admin
          - age1yhm4gctwfmrpz87tdslm550wzqrejk4pcjp5uuvcvy2qzzmvvgxqjp5c8p  # Team member 1
          - age1n3wl9c7yv2tzadcrqk4q9plqthzfvc00v8m0cjlucp2svfj3lxksnw7vvf  # Team member 2
```

4. Re-encrypt secrets:

```bash
sops updatekeys secrets.yaml
```

Now all team members can decrypt and edit secrets using their respective private keys.

## Security Best Practices

1. **Never commit unencrypted secrets** - Always encrypt with sops before committing
2. **Keep private keys secure** - Store age private keys in `~/.config/sops/age/` with 600 permissions
3. **Use strong secrets** - Generate random secrets, never use default or predictable values
4. **Rotate regularly** - Change secrets periodically, especially after team member changes
5. **Limit access** - Only add age keys for team members who need secret access
6. **Backup keys** - Keep encrypted backups of your age private keys
7. **Use different keys per environment** - Consider separate keys for dev/staging/production

## Troubleshooting

### "Failed to get the data key"

- Check that your age private key is in `~/.config/sops/age/keys.txt`
- Verify the public key in `.sops.yaml` matches your private key

### "MAC mismatch"

- The secrets file may be corrupted
- Try re-encrypting from the example file

### "no matching creation rule"

- Check `.sops.yaml` configuration
- Ensure `path_regex` matches your secrets file name

## References

- [sops-nix GitHub](https://github.com/Mic92/sops-nix)
- [sops Documentation](https://github.com/mozilla/sops)
- [age Encryption](https://github.com/FiloSottile/age)
