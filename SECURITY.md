# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest release | Yes |
| Previous minor | Best effort |
| Older | No |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

Please report security vulnerabilities by [opening a GitHub issue](https://github.com/PavelGuzenfeld/standard/issues/new?labels=security&title=Security%3A+).

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Response Timeline

- **Acknowledgment**: within 48 hours
- **Initial assessment**: within 1 week
- **Fix or mitigation**: best effort, typically within 2 weeks for critical issues

## Scope

This policy covers:
- The reusable GitHub Actions workflows in `.github/workflows/`
- The scripts in `scripts/`
- The configuration templates in `configs/`

## Security Best Practices for Consumers

If you use these workflows in your project:

1. **Pin to a release tag or commit SHA** (e.g., `@v1.2.3`) rather than `@main` for production
2. **Review workflow permissions** — only grant what each workflow needs
3. **Use `enable_dangerous_workflows: true`** in `infra-lint.yml` to detect injection patterns in your CI
4. **Enable Dependabot** to keep action versions current
5. **Add a SECURITY.md** to your own repo (template available in `configs/SECURITY.md`)
