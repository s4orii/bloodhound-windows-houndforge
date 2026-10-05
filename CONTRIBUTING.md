# Contributing

Contributions that improve compatibility, safety, documentation, or error
handling are welcome.

## Before submitting a pull request

1. Test on a clean Windows 10 or Windows 11 system with WSL2.
2. Confirm that rerunning the installer preserves existing Docker volumes.
3. Confirm that no container is published on `0.0.0.0` or `[::]`.
4. Parse the PowerShell file to catch syntax errors:

   ```powershell
   $tokens = $null
   $errors = $null
   [System.Management.Automation.Language.Parser]::ParseFile(
       (Resolve-Path '.\Install-BloodHoundCE.ps1'),
       [ref]$tokens,
       [ref]$errors
   ) | Out-Null
   $errors
   ```

5. Never commit credentials, BloodHound exports, client names, IP addresses, or
   assessment evidence.

Keep changes focused and explain the operating systems and WSL distributions
used for testing.
