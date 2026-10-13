# Default WSL alternative

This variant is intended for Windows installations where `wsl.exe --list`
shows a distribution, but commands using `wsl.exe -d <name>` fail with
`WSL_E_DISTRO_NOT_FOUND`, or where a hard-coded Linux account produces
`WSL_E_USER_NOT_FOUND`.

Unlike the standard installer, this version always operates on the WSL
distribution and Linux user configured as defaults for the current Windows
account. Docker administration still runs as `root` inside that default
distribution.

Run it from PowerShell as the same Windows user that normally opens WSL:

```powershell
.\Install-BloodHoundCE.ps1 -OpenBrowser
```

Do not launch it under a different Windows account or with a different
elevation context unless that account owns the same WSL registration. WSL
distributions are registered per Windows user.

The generated desktop controls:

- do not use `-d <distribution>`;
- do not hard-code a Linux username;
- verify Docker before starting BloodHound;
- wait up to 60 seconds for the local UI before opening the browser;
- retain the local-only network bindings and persistent Docker volumes used by
  the standard installer.

Use the standard installer in the repository root when explicit distribution
selection works normally.
