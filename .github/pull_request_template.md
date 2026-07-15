# Pull Request

## Summary
<!-- What does this change do and why? -->

## Change type
- [ ] Terraform (State 1 — foundation)
- [ ] Terraform (State 2 — backup solution)
- [ ] Backup container / scripts
- [ ] Database schema / migrations
- [ ] CI/CD workflows
- [ ] Documentation

## Checklists
- [ ] `terraform fmt -recursive` clean
- [ ] `terraform validate` passes for affected root(s)
- [ ] tflint + Checkov/tfsec pass
- [ ] ShellCheck passes for changed scripts
- [ ] Trivy scan clean (image/filesystem) if applicable
- [ ] No secrets added to code, tfvars, outputs, logs, or images
- [ ] Docs updated (`docs/`) where behavior changed
- [ ] Deployment order / two-state separation preserved (no circular dependency)

## Security impact
<!-- RBAC changes, network exposure, data handling, etc. -->

## Deployment notes
<!-- Any manual steps, approvals, or ordering constraints. -->
