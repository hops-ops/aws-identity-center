# configuration-aws-identity-center

Manage AWS IAM Identity Center (SSO) as code. Define groups, users, permission sets, and account assignments in a single resource.

## Why Identity Center?

**Without Identity Center:**
- IAM users with long-lived access keys
- Separate credentials per account
- No central audit of who accessed what
- Password management nightmare

**With Identity Center:**
- Single sign-on across all AWS accounts
- Time-limited credentials (no access keys)
- Federate with Google, Okta, Azure AD
- Central audit trail in CloudTrail
- One place to revoke access

## Prerequisites

Identity Center must be enabled manually in AWS (one-time setup):

1. Go to [IAM Identity Center console](https://console.aws.amazon.com/singlesignon)
2. Click **Enable** and choose **Enable with AWS Organizations**
3. Note the **Instance ARN** and **Identity Store ID** from Settings

## The Journey

### Stage 1: Basic SSO Setup

Start with a single admin group and permission set.

**Why groups over direct user assignments?**
- Easier to manage as team grows
- Add/remove users without touching permission sets
- Audit who has access via group membership

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IdentityCenter
metadata:
  name: my-sso
  namespace: default
spec:
  managementPolicies: ["*"]
  providerConfigName: default
  region: us-east-1  # Must match where you enabled Identity Center

  # From AWS console: IAM Identity Center > Settings
  identityStoreId: d-1234567890
  identityCenter:
    instanceArn: arn:aws:sso:::instance/ssoins-abcdef0123456789
    sessionDuration: PT4H  # 4-hour sessions

  groups:
    - name: Administrators
      description: Full administrative access

  permissionSets:
    - name: AdministratorAccess
      description: Full admin access
      managedPolicies:
        - arn:aws:iam::aws:policy/AdministratorAccess
      assignToGroups: [Administrators]
      assignToAccounts: ["123456789012"]  # Your account ID
```

### Stage 2: Add Users

Create local users in Identity Store. They'll receive email invitations to set up passwords.

**Why local users?**
- Quick to get started
- No external IdP setup required
- Can migrate to federated later

```yaml
users:
  - username: admin
    email: admin@acme.example.com
    firstName: Admin
    lastName: User
    groups: [Administrators]

  - username: alice
    email: alice@acme.example.com
    firstName: Alice
    lastName: Engineer
    groups: [Developers]
```

### Stage 3: Role-Based Access

Different teams need different access levels. Create groups and permission sets for each role.

**Recommended structure:**
- **Administrators** - Full access, short sessions
- **Developers** - PowerUser without IAM, longer sessions
- **ReadOnly** - View-only for auditors and support
- **SecurityAudit** - Security team cross-account access

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IdentityCenter
metadata:
  name: acme-sso
  namespace: default
spec:
  managementPolicies: ["*"]
  providerConfigName: default
  region: us-east-1
  identityStoreId: d-1234567890
  identityCenter:
    instanceArn: arn:aws:sso:::instance/ssoins-abcdef0123456789

  groups:
    - name: Administrators
      description: Platform team - full access
    - name: Developers
      description: Engineering - deploy and debug
    - name: ReadOnly
      description: Support and auditors
    - name: SecurityTeam
      description: Security engineers

  users:
    - username: platform-admin
      email: platform@acme.example.com
      firstName: Platform
      lastName: Admin
      groups: [Administrators]

    - username: alice
      email: alice@acme.example.com
      firstName: Alice
      lastName: Engineer
      groups: [Developers]

    - username: bob
      email: bob@acme.example.com
      firstName: Bob
      lastName: Support
      groups: [ReadOnly]

  permissionSets:
    - name: AdministratorAccess
      description: Full admin - use sparingly
      sessionDuration: PT2H  # Short sessions for safety
      managedPolicies:
        - arn:aws:iam::aws:policy/AdministratorAccess
      assignToGroups: [Administrators]
      assignToAccounts: ["111111111111", "222222222222"]

    - name: DeveloperAccess
      description: Deploy and debug without IAM
      sessionDuration: PT8H  # Longer for productivity
      managedPolicies:
        - arn:aws:iam::aws:policy/PowerUserAccess
      assignToGroups: [Developers]
      assignToAccounts: ["222222222222"]  # Dev account only

    - name: ViewOnlyAccess
      description: Read-only for support
      sessionDuration: PT1H
      managedPolicies:
        - arn:aws:iam::aws:policy/ViewOnlyAccess
      assignToGroups: [ReadOnly]
      assignToAccounts: ["111111111111", "222222222222"]

    - name: SecurityAudit
      description: Security team audit access
      managedPolicies:
        - arn:aws:iam::aws:policy/SecurityAudit
      assignToGroups: [SecurityTeam]
      assignToAccounts: ["111111111111", "222222222222"]
```

### Stage 4: Custom Policies

Need more granular control? Use inline policies or customer-managed policies.

**When to use each:**
- **Managed policies** - AWS-provided, broad permissions
- **Inline policies** - Custom restrictions, deny statements
- **Customer-managed** - Reusable custom policies in IAM

```yaml
permissionSets:
  - name: RestrictedDeveloper
    description: Developer with guardrails
    sessionDuration: PT8H
    managedPolicies:
      - arn:aws:iam::aws:policy/PowerUserAccess
    # Add restrictions via inline policy
    inlinePolicy: |
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Deny",
            "Action": [
              "iam:*",
              "organizations:*",
              "aws-portal:*"
            ],
            "Resource": "*"
          },
          {
            "Effect": "Deny",
            "Action": "ec2:*",
            "Resource": "*",
            "Condition": {
              "StringNotEquals": {
                "ec2:Region": ["us-east-1", "us-west-2"]
              }
            }
          }
        ]
      }
    assignToGroups: [Developers]
    assignToAccounts: ["222222222222"]
```

### Stage 5: Import Existing Resources

Already have Identity Center configured? Import existing groups, users, and permission sets.

**Why import?**
- Preserve existing configurations
- No disruption to current access
- Gradually bring under Crossplane management

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IdentityCenter
metadata:
  name: existing-sso
  namespace: default
spec:
  managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]
  providerConfigName: default
  region: us-east-1
  identityStoreId: d-1234567890
  identityCenter:
    instanceArn: arn:aws:sso:::instance/ssoins-abcdef0123456789

  groups:
    - name: Administrators
      # Import existing group by ID
      externalName: d1fb9590-0091-7072-55a4-dd0778f5d5cb
      managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]

  users:
    - username: admin
      email: admin@acme.example.com
      firstName: Admin
      lastName: User
      # Import existing user
      externalName: 217be550-1051-7016-a428-1864e5e57e75
      managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]
      groups: [Administrators]
      # Import existing group membership
      groupMembershipExternalNames:
        Administrators: 115b85b0-f0c1-70ae-802f-41695fa2f655

  permissionSets:
    - name: AdministratorAccess
      # Format: PERMISSION_SET_ARN,INSTANCE_ARN
      externalName: arn:aws:sso:::permissionSet/ssoins-abcdef/ps-12345678,arn:aws:sso:::instance/ssoins-abcdef
      managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]
      managedPolicies:
        - arn:aws:iam::aws:policy/AdministratorAccess
```

## Accessing AWS

After Identity Center is ready:

1. Get the AWS Access Portal URL from IAM Identity Center > Settings
2. Users receive email invitations to set passwords
3. Sign in at the portal URL
4. Select an account and permission set
5. Click "Management console" or get CLI credentials

## Status

IdentityCenter exposes IDs for debugging and downstream use:

```yaml
status:
  identityCenter:
    instanceArn: arn:aws:sso:::instance/ssoins-abcdef
    ready: true
  identityStore:
    id: d-1234567890
    groups:
      - name: Administrators
        id: d1fb9590-0091-7072-55a4-dd0778f5d5cb
    users:
      - name: admin
        id: 217be550-1051-7016-a428-1864e5e57e75
  permissionSets:
    - name: AdministratorAccess
      arn: arn:aws:sso:::permissionSet/ssoins-abcdef/ps-12345678
```

## Recommendations

1. **Use groups, not direct user assignments** - Easier to manage at scale
2. **Short sessions for admin access** - PT2H or less for AdministratorAccess
3. **Longer sessions for daily work** - PT8H for developers improves productivity
4. **Deny dangerous actions via inline policy** - Add guardrails to PowerUserAccess
5. **Don't delete users from Identity Store** - Orphan them with managementPolicies instead
6. **Federate when ready** - Start with local users, migrate to IdP later

## Development

```bash
make render              # Render default example
make test                # Run tests
make validate            # Validate compositions
make e2e                 # E2E tests
```

## License

Apache-2.0
