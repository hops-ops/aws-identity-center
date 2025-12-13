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

## Setup

### Step 1: Enable AWS IAM Identity Center (Manual)

AWS IAM Identity Center must be enabled manually in your AWS Organization's management account. This is a one-time setup per organization.

1. **Sign in to the AWS Management Console** as a user with administrator permissions in your organization's management account.

2. **Navigate to IAM Identity Center**:
   - Go to the [IAM Identity Center console](https://console.aws.amazon.com/singlesignon)
   - Or search for "IAM Identity Center" (formerly "AWS SSO") in the AWS Console search bar

3. **Enable IAM Identity Center**:
   - Click **Enable** if this is your first time
   - Choose **Enable with AWS Organizations** (recommended)
   - Select your preferred region (e.g., `us-east-1`) - this will be where your Identity Center instance lives
   - Click **Create AWS organization** if you don't already have one (usually, you'd do this first with hops-ops/configurations-aws-organization)

4. **Note the Instance Details** (you'll need these for Crossplane):
   - After enabling, go to **Settings** in the IAM Identity Center console
   - Copy the **Instance ARN** (format: `arn:aws:sso:::instance/ssoins-xxxxxxxxxx`)
   - Copy the **Identity store ID** (format: `d-xxxxxxxxxx`)
   - Note the **AWS Region** where Identity Center is enabled

5. **Configure Identity Source** (optional):
   - By default, Identity Center uses its built-in directory
   - You can connect to Active Directory or an external identity provider later
   - For this configuration, the built-in Identity Store works fine

### Step 2: Set Up Crossplane AWS Providers

Ensure your Crossplane AWS providers are configured with appropriate credentials:

```yaml
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: aws-provider
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-creds
      key: credentials
```

The credentials must have permissions for:
- `identitystore:*`
- `sso:*`
- `sso-admin:*`

**Example IAM Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sso:*",
        "sso-admin:*",
        "identitystore:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Step 3: Install the Configuration

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: configuration-aws-identity-center
spec:
  package: ghcr.io/hops-ops/configuration-aws-identity-center:latest
  skipDependencyResolution: true
```

Wait for the configuration and its dependencies to become healthy:

```bash
kubectl get configurations
kubectl get providers
```

### Step 4: Create Your First IdentityCenter Resource

Use the instance ARN, Identity Store ID, and region you collected in Step 1 to create an IdentityCenter resource:

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
  region: us-east-1  # Must match where you enabled Identity Center
  identityStoreId: d-1234567890  # From Step 1
  identityCenter:
    instanceArn: arn:aws:sso:::instance/ssoins-1234567890abcdef  # From Step 1
    sessionDuration: PT2H
  groups:
    - name: Admins
      displayName: Platform Admins
  users:
    - username: admin
      email: admin@example.com
      firstName: Admin
      lastName: User
      groups: [Admins]
  permissionSets:
    - name: AdminAccess
      description: Full administrator access
      managedPolicies:
        - arn:aws:iam::aws:policy/AdministratorAccess
      assignToGroups: [Admins]
      assignToAccounts: ["123456789012"]  # Your AWS account ID
```

Apply it:

```bash
kubectl apply -f platform-sso.yaml
```

Watch the resources reconcile:

```bash
# Watch the main composite
kubectl get identitycenters -n default

# Check individual managed resources
kubectl get users,groups,groupmemberships -n default
kubectl get permissionsets,accountassignments -n default
```

### Step 5: Access the AWS Console

Once the IdentityCenter resource is Ready:

1. **Get the AWS Access Portal URL**:
   - In the IAM Identity Center console, go to **Settings**
   - Copy the **AWS access portal URL** (format: `https://d-xxxxxxxxxx.awsapps.com/start`)

2. **Set up your user's password**:
   - In the IAM Identity Center console, go to **Users**
   - Find your user (e.g., `admin`)
   - Click **Reset password** and choose **Send email** or **Generate one-time password**
   - If you chose email, check the user's email for the temporary password

3. **Sign in**:
   - Go to the AWS access portal URL
   - Sign in with the username and password
   - You'll be prompted to set a new password on first login

4. **Configure MFA** (recommended):
   - After signing in, you'll be prompted to register an MFA device
   - Use an authenticator app like Google Authenticator or Authy

5. **Access AWS Accounts**:
   - After authentication, you'll see tiles for each AWS account you have access to
   - Click on an account to see available permission sets
   - Click **Management console** to open the AWS Console with that permission set

## Usage Examples

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
  region: us-east-1
  identityStoreId: d-1234567890
  identityCenter:
    instanceArn: arn:aws:sso:::instance/ssoins-1234567890abcdef
    sessionDuration: PT2H
    relayState: https://console.aws.amazon.com/
  groups:
    - name: Admins
      displayName: Platform Admins
      description: Full administrator access
    - name: Developers
      displayName: Platform Developers
      description: Developer access with guardrails
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
      sessionDuration: PT2H
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

## Troubleshooting

### Resources Not Becoming Ready

Check the status of managed resources:

```bash
# Check all managed resources
kubectl get managed -n default

# Describe a specific resource to see events
kubectl describe user.identitystore.aws.m.upbound.io/<user-name> -n default
kubectl describe permissionset.ssoadmin.aws.m.upbound.io/<ps-name> -n default
```

Common issues:

1. **Wrong instance ARN or Identity Store ID**: Verify the values from the IAM Identity Center console Settings page
2. **Wrong region**: The `spec.region` must match where you enabled Identity Center
3. **Insufficient permissions**: Check your ProviderConfig credentials have the required IAM permissions
4. **Provider not ready**: Ensure `provider-aws-identitystore` and `provider-aws-ssoadmin` are healthy

### User Can't Sign In

1. **Password not set**: In the IAM Identity Center console, go to Users → select user → Reset password
2. **Wrong access portal URL**: Get the correct URL from Settings in the IAM Identity Center console
3. **User not in group**: Verify `spec.users[].groups` includes the expected group names
4. **Account assignment not ready**: Check `kubectl get accountassignments -n default`

### Permission Set Not Appearing

1. **Assignment not created**: Ensure you've specified either `assignToGroups`, `assignToUsers`, or explicit `assignments`
2. **Account ID mismatch**: Verify the account ID in `assignToAccounts` matches your target AWS account
3. **User assignments require observed state**: User assignments need the User resource to be Ready first (uses observed principal ID)

### Checking Status

View the composite status for an overview:

```bash
kubectl get identitycenter platform-sso -n default -o yaml | yq '.status'
```

The status shows:
- `identityCenter.instanceArn` - confirmed instance ARN
- `identityStore.id` - confirmed Identity Store ID
- `identityStore.users[]` - each user with their resolved ID
- `identityStore.groups[]` - each group with their resolved ID
- `permissionSets[]` - each permission set with ARN and account assignments

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
