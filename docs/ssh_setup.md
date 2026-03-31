# SSH Setup

> [← Back to README](../README.md)

## SSH Setup on Windows

RepoHerd uses PuTTY/plink for SSH on Windows.

1. **Convert OpenSSH keys to PuTTY format**:
   - Open PuTTYgen
   - Load your OpenSSH private key
   - Save private key as .ppk file

2. **Configure Pageant**:
   - Start Pageant (will appear in system tray)
   - Right-click Pageant icon → Add Key
   - Browse to your .ppk file
   - Enter passphrase when prompted

3. **Test SSH connection**:

   ```cmd
   plink -i "C:\path\to\key.ppk" git@github.com
   ```

## SSH Setup on macOS/Linux

RepoHerd uses OpenSSH (bundled with Git or the OS) on macOS and Linux. No additional tools are required.

1. **Use standard OpenSSH keys** (e.g., `id_ed25519`, `id_rsa`):

   ```bash
   # Generate a new key if needed
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

2. **Set correct permissions** (ssh refuses keys that are too permissive):

   ```bash
   chmod 600 ~/.ssh/id_ed25519
   ```

3. **Create `git_credentials.json`** mapping hostnames to your key paths:

   ```json
   {
     "github.com": "/home/username/.ssh/id_ed25519",
     "gitlab.com": "/home/username/.ssh/gitlab_rsa"
   }
   ```

4. **Test SSH connection**:

   ```bash
   ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes git@github.com
   ```

**Note**: If your key has a passphrase and you are running in a non-interactive/CI environment, either use a passphrase-less deploy key or pre-load the key into `ssh-agent` before running RepoHerd.

**Passphrase-protected keys**: If your key has a passphrase, load it into `ssh-agent` before running RepoHerd so it doesn't prompt during git operations:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
# Enter passphrase once — agent handles it for the rest of the session
```

**Converting from PuTTY format**: If you have `.ppk` keys from a Windows setup, convert them using PuTTYgen on Windows (**Conversions → Export OpenSSH key (force new file format)**) or on macOS/Linux:

```bash
# Requires puttygen (install via: brew install putty / apt install putty-tools)
puttygen key.ppk -O private-openssh -o key_openssh
chmod 600 key_openssh
```
