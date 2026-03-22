# Troubleshooting

> [← Back to README](../README.md)

## Common Issues

1. **"Plink.exe not found"** (Windows)
   - Install PuTTY suite
   - Add PuTTY installation directory to PATH

2. **"SSH key is not in PuTTY format"** (Windows)
   - Use PuTTYgen to convert OpenSSH keys to .ppk format

3. **"SSH key is in PuTTY format (.ppk), which is not supported on macOS/Linux"**
   - Convert with: `puttygen key.ppk -O private-openssh -o key_openssh`

4. **"SSH key file has overly permissive permissions"** (macOS/Linux)
   - Run: `chmod 600 /path/to/your/key`

5. **"No SSH key configured for repository"**
   - Check that hostname is correctly specified in git_credentials.json
   - Verify the hostname matches the repository URL

6. **"Filename too long" errors on Windows**
   - Enable long path support: `git config --global core.longpaths true`
   - This is common with repositories containing deeply nested paths (e.g., FPGA/Xilinx projects)

7. **Git LFS errors**
   - Install Git LFS: `git lfs install`
   - Or set `"Skip LFS": true` in configuration

8. **API Incompatibility errors in recursive mode (Agnostic mode)**
   - Review the "API Compatible Tags" for conflicting repositories
   - Check if versions truly are API compatible
   - Consider if compatibility modes need adjustment
   - Tags can be listed in any order - automatic chronological sorting handles temporal ordering

9. **SemVer version conflicts**
   - Verify version requirements are compatible
   - Check that version tags follow your specified regex pattern
   - Review conflict details in error messages for resolution guidance
   - Consider using floating versions (x.y.*, x.*) for more flexible version selection

10. **Floating version pattern errors**
    - Ensure floating patterns use correct syntax: `x.y.*` or `x.*`
    - Verify repository tags match the specified Version Regex pattern
    - Check that compatible versions exist for floating patterns
    - Review debug logs for pattern parsing and version selection details

11. **Tag temporal sorting issues (Agnostic mode)**
    - Verify git tags exist in repositories
    - Check debug logs for tag date fetching errors
    - Ensure repositories are accessible for tag date queries
    - Review verbose output for tag selection decisions

12. **Custom dependency file not found**
    - Verify the custom path and filename are correct
    - Check that the dependency file exists in the specified location
    - Remember that paths are relative to repository root
    - Use debug logging to see resolved paths

13. **Repository path conflicts**
    - Ensure the same repository isn't referenced with different relative paths
    - Check that custom dependency file paths don't create conflicting layouts
    - Verify relative paths resolve correctly from repository roots

14. **Post-checkout script issues**
    - Verify script file exists at the specified location
    - Ensure script has .ps1 extension
    - Check script execution permissions
    - Review debug logs for script execution details
    - Use `-DisablePostCheckoutScripts` to bypass script execution
    - Verify script doesn't exceed 5-minute timeout

## Debug Mode

Enable detailed logging to troubleshoot issues:

```powershell
.\LsiGitCheckout.ps1 -EnableDebug -Verbose
```

Check the generated debug log file for:
- JSON content of all processed dependency files
- Hostname extraction from URLs
- SSH key lookup attempts
- API compatibility calculations
- Compatibility mode interactions
- Tag date fetching operations and chronological sorting
- SemVer version parsing and conflict resolution
- Version pattern recognition (LowestApplicable, FloatingPatch, FloatingMinor)
- Mixed specification mode selection logic
- Custom dependency file path resolution
- Repository root path usage for relative path resolution
- Post-checkout script discovery and execution details
- Detailed Git command execution

## Enhanced Error Context

For advanced debugging, enable detailed error context:

```powershell
.\LsiGitCheckout.ps1 -EnableDebug -EnableErrorContext
```

This provides:
- Full stack traces for all errors
- Line numbers and function names where errors occurred
- Detailed error context for complex dependency resolution scenarios
- Enhanced troubleshooting information for SemVer conflicts
- Floating version pattern parsing and resolution diagnostics
