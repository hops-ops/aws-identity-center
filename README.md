# configuration-aws-identity-center

`configuration-aws-identity-center` publishes the namespaced `IdentityCenter` composite. It provisions a full IAM Identity Center instance per organization, including optional starter local users, Identity Store groups, production-ready permission sets, and deterministic account assignments so teams get AWS Console access minutes after the root account exists.

## Features

- **Namespaced, Crossplane 2.0 ready** – `IdentityCenter` is scoped to namespaces, carries `managementPolicies`, and exposes a structured status so you can multi-tenant access provisioning with confidence.
- **Root-account aware** – `spec.forProvider.rootAccountRef` keeps the Identity Center instance aligned with the root AWS account you already manage via the `Account` composite. Provider configs default to that account, so day-one bootstrap is copy/paste simple.
- **Identity Store automation** – declare starter groups and local users (emails, names, default group memberships). The composition fans these out into Identity Store `Group`, `User`, and `GroupMembership` resources.
- **Opinionated permission sets** – ship turnkey AWS managed policies plus optional inline or customer-managed attachments. Use `assignToGroups`, `assignToUsers`, and `assignToAccounts` to describe access at a high level; the composition renders the cross-product into AWS `AccountAssignment` resources. Explicit overrides are still available via `permissionSets[].assignments`.
- **Observability + safety** – the render function projects Identity Store IDs, permission set ARNs, and assignment metadata back into status and only emits `Usage` objects once the upstream resources report Ready.
- **CI + tests** – focused examples under `examples/identitycenters/` plus KCL regression tests (`tests/test-render`) keep behavioural drift out of main.

## Prerequisites

- Crossplane v1.15+ running in your control plane.
- Crossplane packages:
  - `provider-aws-identitystore` (≥ v2.2.0)
  - `provider-aws-ssoadmin` (≥ v2.2.0)
  - `function-auto-ready` (≥ v0.5.1)

Stick with the `crossplane-contrib` packages listed above—Upbound-hosted variants now require paid accounts and break our OSS workflow.

## Install

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: configuration-aws-identity-center
spec:
  package: ghcr.io/hops-ops/configuration-aws-identity-center:latest
  skipDependencyResolution: true
```

## Example Composite

**Minimal example:**

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IdentityCenter
metadata:
  name: platform-sso
  namespace: default
spec:
  managementPolicies: ["*"]
  providerConfigName: aws-provider
  identityCenter:
    instanceArn: arn:aws:sso:::instance/ssoins-1234567890abcdef
  identityStore:
    id: d-1234567890
  groups:
    - name: Admins
  users:
    - username: admin
      email: admin@example.com
      groups: [Admins]
  permissionSets:
    - name: AdminAccess
      managedPolicies:
        - arn:aws:iam::aws:policy/AdministratorAccess
      assignToGroups: [Admins]
      assignToAccounts: ["123456789012"]
```

**Complete example with all options:**

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IdentityCenter
metadata:
  name: platform-sso
  namespace: default
spec:
  organizationName: platform
  managementMode: self
  managementPolicies: ["*"]
  providerConfigName: aws-provider
  identityCenter:
    instanceArn: arn:aws:sso:::instance/ssoins-1234567890abcdef
    sessionDuration: PT2H
    relayState: https://console.aws.amazon.com/
  identityStore:
    id: d-1234567890
  groups:
    - name: Admins
      displayName: Platform Admins
    - name: Developers
      displayName: Platform Developers
  users:
    - username: admin
      email: admin@example.com
      firstName: Admin
      lastName: User
      groups: [Admins]
    - username: dev-1
      email: dev1@example.com
      firstName: Dev
      lastName: One
      groups: [Developers]
  permissionSets:
    - name: HopsAdministratorAccess
      description: Full admin – use sparingly
      managedPolicies:
        - arn:aws:iam::aws:policy/AdministratorAccess
      assignToGroups: [Admins]
      assignToAccounts: ["123456789012"]
    - name: HopsDeveloperAccess
      description: Safe developer defaults
      sessionDuration: PT8H
      managedPolicies:
        - arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
        - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
      inlinePolicy: |
        {
          "Version": "2012-10-17",
          "Statement": [
            {"Effect": "Deny", "Action": ["iam:*", "aws-portal:*"], "Resource": "*"}
          ]
        }
      assignToGroups: [Developers]
      assignToAccounts: ["210987654321"]
```

This renders the Identity Store users/groups (plus GroupMemberships), then the permission sets, inline or managed policy attachments, optional customer managed policy attachments, and the account assignments derived from `assignTo*`. Logical names are slugified automatically so you can keep AWS-friendly display names.

## Development

- `make clean` – remove `_output/` and `.up/` artefacts.
- `make build` – rebuild the configuration package via `up project build`.
- `make render` / `make render-all` – render examples with `up composition render`.
- `make validate` – validate the XRD + examples with `crossplane beta validate`.
- `make test` – run `up test run tests/test-*`.
- `make publish tag=<version>` – build and push configuration + render function images.
- `make e2e` – execute the AWS-backed suite under `tests/e2etest-identity-center` (requires valid `aws-creds` and instance metadata).

Update the schema, examples, tests, README, and `AGENTS.md` together whenever you add new inputs.

## Support

- **Issues**: [github.com/hops-ops/configuration-aws-identity-center/issues](https://github.com/hops-ops/configuration-aws-identity-center/issues)
- **Discussions**: [github.com/hops-ops/configuration-aws-identity-center/discussions](https://github.com/hops-ops/configuration-aws-identity-center/discussions)
