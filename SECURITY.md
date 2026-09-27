# Security Policy

## Reporting a Vulnerability

If you discover a security issue, please report it privately.

- Email: security@collegesapien.com
- Or open a GitHub Security Advisory if available for this repository

Please do not open public issues for security vulnerabilities. We will respond
as quickly as possible and work with you to understand and address the issue.

## Supported Versions

Security updates are applied to the `main` branch and the latest release.

## Response Headers

Every browser-facing surface in this repo ships a baseline set of security
response headers (CSP, HSTS, `X-Content-Type-Options`, `X-Frame-Options`,
`Referrer-Policy`, `Permissions-Policy`, COOP). See
[SECURITY_HEADERS.md](./SECURITY_HEADERS.md) for where each is configured and
why the non-obvious exceptions exist.

If you are changing any of them, please read that file first — several
directives look over-permissive and are load-bearing.
