# LsiGitCheckout

A PowerShell script for managing multiple Git repositories with support for tags, SSH authentication via PuTTY, Git LFS, and submodules.

## Features

- **Batch Operations**: Clone or update multiple Git repositories from a single JSON configuration file
- **Tag Support**: Automatically checkout specific tags for each repository
- **PuTTY/Pageant Integration**: SSH authentication using PuTTY format keys (.ppk)
- **Secure Credentials Management**: SSH keys stored separately from repository configuration
- **Submodule Support**: Handles Git submodules with automatic SSH key lookup
- **Git LFS Support**: Optional Git LFS content management with skip functionality
- **Smart Reset**: Automatically resets repositories to clean state before checkout
- **Error Handling**: Comprehensive logging and user-friendly error dialogs
- **Dry Run Mode**: Preview operations without making changes

## Requirements

- **Operating System**: Windows 10/11 or Windows Server 2016+
- **PowerShell**: Version 5.1 or higher
- **Git**: Git for Windows (https://git-scm.com/download/win)
- **PuTTY Suite**: For SSH authentication (https://www.putty.org/)
  - plink.exe must be in PATH
  - pageant.exe for SSH key management
- **Git LFS**: Optional, for Large File Storage support (https://git-lfs.github.com/)

## Installation

1. Download `LsiGitCheckout.ps1` to your desired location
2. Create `dependencies.json` with your repository configuration
3. Create `git_credentials.json` with your SSH key mappings (if using SSH)
4. Ensure execution policy allows running scripts:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## Usage

### Basic Usage

```powershell
# Use default dependencies.json and git_credentials.json in script directory
.\LsiGitCheckout.ps1

# Specify custom JSON files
.\LsiGitCheckout.ps1 -InputFile "C:\configs\myrepos.json" -CredentialsFile "C:\configs\my_credentials.json"

# Enable debug logging
.\LsiGitCheckout.ps1 -EnableDebugLog

# Dry run mode (preview without changes)
.\LsiGitCheckout.ps1 -DryRun

# Verbose output
.\LsiGitCheckout.ps1 -Verbose
```

### Parameters

- `-InputFile`: Path to repository configuration file (default: dependencies.json)
- `-CredentialsFile`: Path to SSH credentials file (default: git_credentials.json)
- `-DryRun`: Preview operations without making changes
- `-EnableDebugLog`: Create detailed debug log file
- `-Verbose`: Show verbose output messages

## Configuration Files

### dependencies.json

Contains repository configurations without any credential information:

```json
[
  {
    "Repository URL": "https://github.com/user/repo.git",
    "Base Path": "repos/my-repo",
    "Tag": "v1.0.0",
    "Skip LFS": false,
    "Submodule Config": [
      {
        "Submodule Name": "submodule1"
      }
    ]
  }
]
```

**Configuration Options:**
- **Repository URL** (required): Git repository URL (HTTPS or SSH)
- **Base Path** (required): Local directory path (relative or absolute)
- **Tag** (required): Git tag to checkout
- **Skip LFS** (optional): Skip Git LFS downloads for this repository and all submodules
- **Submodule Config** (optional): Array of submodule configurations (SSH keys looked up automatically)

### git_credentials.json

Maps hostnames to SSH key files:

```json
{
  "github.com": "C:\\Users\\username\\.ssh\\github_key.ppk",
  "gitlab.com": "C:\\Users\\username\\.ssh\\gitlab_key.ppk",
  "bitbucket.org": "C:\\Users\\username\\.ssh\\bitbucket_key.ppk",
  "ssh://git.internal.corp": "C:\\keys\\internal_key.ppk"
}
```

**Notes:**
- Keys are hostname-based (extracted from repository URLs)
- Supports hostnames with or without `ssh://` prefix
- All SSH keys must be in PuTTY format (.ppk)
- This file should NOT be committed to version control

## Examples

### Example 1: Public Repositories

Create `dependencies.json`:

```json
[
  {
    "Repository URL": "https://github.com/microsoft/terminal.git",
    "Base Path": "repos/windows-terminal",
    "Tag": "v1.19.10573.0"
  },
  {
    "Repository URL": "https://github.com/PowerShell/PowerShell.git",
    "Base Path": "repos/powershell",
    "Tag": "v7.4.1",
    "Skip LFS": true
  }
]
```

No credentials file needed for public repositories. Run:
```powershell
.\LsiGitCheckout.ps1
```

### Example 2: Private Repository with SSH

Create `dependencies.json`:
```json
[
  {
    "Repository URL": "git@github.com:mycompany/private-repo.git",
    "Base Path": "C:\\Projects\\private-repo",
    "Tag": "release-2024.1"
  }
]
```

Create `git_credentials.json`:
```json
{
  "github.com": "C:\\Users\\john\\.ssh\\github_company.ppk"
}
```

### Example 3: Repository with SSH Submodules

Create `dependencies.json`:
```json
[
  {
    "Repository URL": "https://github.com/myorg/main-project.git",
    "Base Path": "repos/main-project",
    "Tag": "v2.0.0",
    "Submodule Config": [
      {
        "Submodule Name": "auth-module"
      },
      {
        "Submodule Path": "libs/common"
      }
    ]
  }
]
```

Create `git_credentials.json`:
```json
{
  "github.com": "C:\\keys\\github_deploy.ppk",
  "gitlab.com": "C:\\keys\\gitlab_deploy.ppk",
  "internal.company.com": "C:\\keys\\internal_deploy.ppk"
}
```

The script will automatically use the appropriate SSH key based on each submodule's URL hostname.

## Security Best Practices

1. **Never commit `git_credentials.json` to version control**
   - Add it to your `.gitignore` file
   - Use `git_credentials.example.json` as a template

2. **Protect your SSH key files**
   - Store keys in a secure location
   - Use appropriate file permissions
   - Use passphrases on your keys

3. **Use separate keys for different services**
   - Don't reuse the same SSH key across multiple services
   - Use deployment-specific keys with limited permissions

## SSH Setup with PuTTY

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

## Workflow

1. **Load Credentials**: Reads SSH key mappings from git_credentials.json
2. **Parse Configuration**: Reads repository list from dependencies.json
3. **For Each Repository**:
   - Extract hostname from URL
   - Look up SSH key if needed
   - Clone or update repository
   - Checkout specified tag
   - Handle submodules with automatic SSH key lookup
   - Process Git LFS if not skipped

## Output

- **Console Output**: Color-coded status messages
- **Error Log**: `LsiGitCheckout_Errors.txt` in script directory
- **Debug Log**: Timestamped log file when using `-EnableDebugLog`

## Troubleshooting

### Common Issues

1. **"Plink.exe not found"**
   - Install PuTTY suite
   - Add PuTTY installation directory to PATH

2. **"SSH key is not in PuTTY format"**
   - Use PuTTYgen to convert OpenSSH keys to .ppk format

3. **"No SSH key configured for repository"**
   - Check that hostname is correctly specified in git_credentials.json
   - Verify the hostname matches the repository URL

4. **Git LFS errors**
   - Install Git LFS: `git lfs install`
   - Or set `"Skip LFS": true` in configuration

### Debug Mode

Enable detailed logging to troubleshoot issues:

```powershell
.\LsiGitCheckout.ps1 -EnableDebugLog -Verbose
```

Check the generated debug log file for:
- Hostname extraction from URLs
- SSH key lookup attempts
- Detailed Git command execution

## Migration from Version 2.x

If upgrading from version 2.x:

1. Create `git_credentials.json` with your SSH key mappings
2. Remove all "SSH Key Path" fields from dependencies.json
3. The script will now look up SSH keys based on repository hostnames

Example migration:

**Old (v2.x) dependencies.json:**
```json
{
  "Repository URL": "git@github.com:mycompany/repo.git",
  "SSH Key Path": "C:\\keys\\github.ppk",
  ...
}
```

**New (v3.x) dependencies.json:**
```json
{
  "Repository URL": "git@github.com:mycompany/repo.git",
  ...
}
```

**New git_credentials.json:**
```json
{
  "github.com": "C:\\keys\\github.ppk"
}
```

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Authors

Originally developed by LS Instruments AG for managing complex multi-repository projects.

Co-authored with Claude (Anthropic) through collaborative development.