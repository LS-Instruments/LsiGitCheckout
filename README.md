# LsiGitCheckout

A PowerShell script for managing multiple Git repositories with support for tags, SSH authentication via PuTTY, Git LFS, and submodules.

## Features

- **Batch Operations**: Clone or update multiple Git repositories from a single JSON configuration file
- **Tag Support**: Automatically checkout specific tags for each repository
- **PuTTY/Pageant Integration**: SSH authentication using PuTTY format keys (.ppk)
- **Submodule Support**: Handles Git submodules with individual SSH key configuration
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
2. Ensure execution policy allows running scripts:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## Usage

### Basic Usage

```powershell
# Use default dependencies.json in script directory
.\LsiGitCheckout.ps1

# Specify custom JSON file
.\LsiGitCheckout.ps1 -InputFile "C:\configs\myrepos.json"

# Enable debug logging
.\LsiGitCheckout.ps1 -EnableDebugLog

# Dry run mode (preview without changes)
.\LsiGitCheckout.ps1 -DryRun

# Verbose output
.\LsiGitCheckout.ps1 -Verbose
```

### Parameters

- `-InputFile`: Path to JSON configuration file (default: dependencies.json)
- `-DryRun`: Preview operations without making changes
- `-EnableDebugLog`: Create detailed debug log file
- `-Verbose`: Show verbose output messages

## Configuration Format

Create a JSON file with an array of repository configurations:

```json
[
  {
    "Repository URL": "https://github.com/user/repo.git",
    "Base Path": "repos/my-repo",
    "Tag": "v1.0.0",
    "Skip LFS": false,
    "SSH Key Path": "C:\\Users\\user\\.ssh\\key.ppk",
    "Submodule Config": [
      {
        "Submodule Name": "submodule1",
        "SSH Key Path": "C:\\Users\\user\\.ssh\\submodule1.ppk"
      }
    ]
  }
]
```

### Configuration Options

- **Repository URL** (required): Git repository URL (HTTPS or SSH)
- **Base Path** (required): Local directory path (relative or absolute)
- **Tag** (required): Git tag to checkout
- **Skip LFS** (optional): Skip Git LFS downloads for this repository and all submodules
- **SSH Key Path** (optional): Path to PuTTY format (.ppk) SSH key
- **Submodule Config** (optional): Array of submodule-specific configurations

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
  },
  {
    "Repository URL": "https://github.com/git-for-windows/git.git",
    "Base Path": "repos/git-for-windows",
    "Tag": "v2.43.0.windows.1"
  }
]
```

Then run:
```powershell
.\LsiGitCheckout.ps1
```

### Example 2: Private Repository with SSH

```json
[
  {
    "Repository URL": "git@github.com:mycompany/private-repo.git",
    "Base Path": "C:\\Projects\\private-repo",
    "Tag": "release-2024.1",
    "SSH Key Path": "C:\\Users\\john\\.ssh\\github_key.ppk"
  }
]
```

### Example 3: Repository with Submodules

```json
[
  {
    "Repository URL": "https://github.com/myorg/main-project.git",
    "Base Path": "repos/main-project",
    "Tag": "v2.0.0",
    "Submodule Config": [
      {
        "Submodule Name": "auth-module",
        "SSH Key Path": "C:\\keys\\auth_deploy.ppk"
      },
      {
        "Submodule Path": "libs/common",
        "SSH Key Path": "C:\\keys\\common_deploy.ppk"
      }
    ]
  }
]
```

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

1. **Parse Configuration**: Reads JSON file and validates entries
2. **Check Existing**: For each repository:
   - If exists with correct URL → Reset to clean state
   - If exists with different URL → Prompt user
   - If doesn't exist → Create directory
3. **Clone/Update**: 
   - Clone new repositories or fetch updates
   - Skip LFS if configured
4. **Checkout Tag**: Switch to specified tag
5. **Handle Submodules**: Initialize and update with individual SSH keys
6. **Git LFS**: Pull LFS content unless skipped

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

3. **"Pageant not running"**
   - Start Pageant before running script
   - Add your SSH keys to Pageant

4. **Git LFS errors**
   - Install Git LFS: `git lfs install`
   - Or set `"Skip LFS": true` in configuration

### Debug Mode

Enable detailed logging to troubleshoot issues:

```powershell
.\LsiGitCheckout.ps1 -EnableDebugLog -Verbose
```

Check the generated debug log file for detailed execution information.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Authors

Originally developed by LS Instruments AG for managing complex multi-repository projects.

Co-authored with Claude (Anthropic) through collaborative development.