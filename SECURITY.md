# Security policy

## Reporting a vulnerability

Please report suspected vulnerabilities through a private GitHub security
advisory instead of opening a public issue. Include the affected version,
reproduction steps, expected impact, and any suggested mitigation.

Do not include credentials, client data, directory exports, or other sensitive
material in public issues.

## Security model

This project installs third-party packages and the official BloodHound CLI from
their upstream distribution channels. The installer:

- uses HTTPS package and release endpoints;
- validates the downloaded archive structure before extraction;
- binds published container ports to localhost;
- prevents broad Docker port publication through a post-installation check;
- stores generated credentials only in the selected WSL user's configuration;
- does not collect telemetry or transmit BloodHound data.

Users remain responsible for reviewing upstream releases and operating the
tool only in authorized environments.
