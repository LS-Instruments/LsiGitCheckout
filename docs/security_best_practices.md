# Security Best Practices

> [← Back to README](../README.md)

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

4. **Post-Checkout Script Security**
   - Review post-checkout scripts before execution
   - Ensure scripts are version controlled within repositories
   - Use `-DisablePostCheckoutScripts` in untrusted environments
   - Monitor script execution logs for security events
