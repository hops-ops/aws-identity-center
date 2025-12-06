# AWS Identity Center Config Agent Guide

This repository publishes the `IdentityCenter` configuration package. Use this guide any time you modify schemas, templates, docs, CI, or release automation.

## Repository Layout

- `apis/`: XRD (`definition.yaml`), composition, and package metadata. Changes here define the public contract.
- `examples/`: Renderable `IdentityCenter` specs. Keep them minimal and refresh whenever the schema changes.
- `functions/render/`: Go-template pipeline executed by `up composition render`. Files execute lexically—reserve `00-` for common variables, `10-` for Identity Store principals, `20-` for permission sets, and keep `90-`/`99-` reserved for observed values + status.
- `tests/`: KCL-based regression tests (`up test`). Add focused assertions when introducing new behaviour.
- `.github/` & `.gitops/`: CI + GitOps workflows. Maintain structural parity between them; only adjust repo-specific defaults such as image names or registry references.
- `_output/` & `.up/`: generated artefacts. `make clean` removes them before a fresh build.

## Contract Overview

`apis/identitycenters/definition.yaml` defines the namespaced `IdentityCenter` XRD with a flattened, developer-friendly API:

- `spec.organizationName` defaults to `metadata.name` and feeds naming/tagging.
- `spec.managementMode` toggles self vs managed operation. `spec.managementPolicies` defaults to `["*"]` and fans out to every rendered resource.
- `spec.providerConfigName` specifies the AWS ProviderConfig used for all API calls. Defaults to `metadata.name`.
- `spec.identityCenter` carries the Identity Center instance ARN plus optional relay state, session duration, and tag overrides. If `instanceArn` is not provided, the composition should create a new instance (TODO: instance creation template).
- `spec.identityStore` sets the identity store ID when rendering groups/users. If not provided, it will be derived from the Identity Center instance.
- `spec.groups[]` / `spec.users[]` declare Identity Store principals at the top level. Users can list the group names they should join; the templates emit `GroupMembership` resources automatically.
- `spec.permissionSets[]` (optional) describes permission sets along with inline policies, managed policy ARNs, customer-managed policy references, and assignment intent (`assignToAccounts`, `assignToGroups`, `assignToUsers`). A legacy `assignments[]` block exists for bespoke tuples.
- `spec.externalIdP` (reserved for Authentik/Okta) is defined but currently a no-op.
- Status surfaces the resolved management mode, Identity Center instance ARN, identity store object IDs, and assignment metadata so platform teams can trace readiness from `kubectl get`.

**Key simplifications from v1:**
- Removed `spec.forProvider` wrapper – all fields now at top level under `spec`
- Removed `spec.forProvider.rootAccountRef` – use `providerConfigName` instead
- Removed per-resource providerConfigs (`identityCenter.providerConfig`, `identityStore.providerConfig`) – use single `spec.providerConfigName` for all AWS resources
- Made `permissionSets` optional to support minimal setups

When introducing new schema knobs, update the XRD, README, examples, tests, and templates in the same change.

## Rendering Guidelines

- Gather all shared values in `functions/render/00-desired-values.yaml.gotmpl`. Default aggressively using `default`, `merge`, etc., so later templates never dereference nil values.
- Mirror the pipeline outlined in `docs/plan/03-identity-center.md`: `00-desired-values`, `10-observed-values`, `20-groups`, `30-users`, `40-permission-sets`, `50-account-assignments`, `60-external-idp`, `98-usages`, `99-status`. Leave plenty of numbering gaps for future growth.
- Only render Identity Store resources when an `identityStore.id` is present. Users without an identity store block should still get permission sets and assignments (use external identifiers).
- Generate `identitystore.aws.m.upbound.io/v1beta1, Kind=GroupMembership` resources whenever a local user references one or more groups. Use `groupIdRef` and `memberIdRef` so Crossplane resolves the IDs.
- Use `setResourceNameAnnotation` to assign stable logical names (`identity-center-user-<name>`, `permission-set-<name>`, etc.). Observed-state and Usage gating rely on these annotations.
- Always include `managementPolicies` and `providerConfigRef.kind: ProviderConfig` on managed resources to stay compliant with Crossplane 2.0 expectations.
- Target Crossplane 2+: skip `deletionPolicy` on managed resources; rely on `managementPolicies` and defaults.
- Merge caller-supplied tag maps with the default `{"hops": "true", "organization": <name>}` map before applying them to permission sets and propagated resources.

## Testing

`tests/test-render/main.k` currently covers two scenarios:

1. **Minimal** – renders starter groups + users, confirms `GroupMembership` resources are emitted, and checks the admin permission set plus group-based account assignment.
2. **Inline policy & custom policies** – verifies inline policy wiring, customer-managed policy attachments, and explicit user assignments that bypass group references.

Use additional examples under `examples/identitycenters/` plus new assertions when adding behaviour.

Run `make test` (or `up test run tests/test-*`) after touching templates or schema. Tests should focus on behaviour—assert only the fields that should never change.

### E2E suite

`tests/e2etest-identity-center/main.k` provisions a real `IdentityCenter` composite and validates it against AWS. To run it locally:

1. Provide disposable AWS credentials via `tests/e2etest-identity-center/aws-creds` (gitignored). The file should contain a `[default]` profile understood by the AWS SDK (same format used by `aws configure`).
2. Update the `_instance_arn`, `_identity_store_id`, and `_target_account` constants in `main.k` so they point at the Identity Center instance dedicated to e2e.
3. Run `make e2e` (or `up test run tests/e2etest-identity-center --e2e`). The harness injects the `aws-creds` Secret and creates an `aws.m.upbound.io/v1beta1, Kind=ProviderConfig` so the composition can authenticate.
4. Keep `aws-creds` out of git—it's ignored on purpose. Rotate the credentials frequently since this suite touches IAM Identity Center.

## Tooling & Automation

- `make render`, `make render-all`, `make validate`, `make test`, `make publish tag=<version>` mirror other configuration repos.
- `.github/workflows` and `.gitops/` both use `unbounded-tech/workflows-crossplane` v0.8.0. Update both locations together if you bump versions.
- Renovate (`renovate.json`) follows the standard template; extend it here if you need custom behaviour.

## Provider Guidance

Use the `crossplane-contrib` providers defined in `upbound.yaml`. Avoid the Upbound-hosted configuration packages—they now require paid accounts and conflict with our OSS-first workflow. Repeat this reminder in every repo-level `AGENTS.md` you touch.
