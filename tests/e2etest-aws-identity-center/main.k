import base64
import datetime
import file
import math
import models.ai.com.ops.hops.aws.v1alpha1 as hops
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.dev.meta.v2alpha1 as metav2alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

_now = str(int(math.floor(datetime.ticks())))

_creds = file.read("secrets/aws-creds")
_base64_creds = base64.encode(_creds)

# =============================================================================
# Persistent infrastructure - update these if re-creating the test environment
# =============================================================================

# Identity Center instance - AWS only allows one per organization
# Get these values with: aws sso-admin list-instances
_instance_arn = "arn:aws:sso:::instance/ssoins-668444b406cda8b2"
_identity_store_id = "d-9a675288a4"
_region = "us-east-2"

# Target account for testing permission set assignments
_target_account = "544051101726"

# Admins group - fill ID after first run for persistence
_persistent_group_name = "Admins"
_persistent_group_id = "710b35f0-2061-7026-da5c-b5cd9f22002d"  # aws identitystore list-groups --identity-store-id d-9a675288a4

# Pat - admin user
_persistent_user_name = "pat"
_persistent_user_id = "f19b25a0-10c1-70fa-808b-d3da146d8aa5"  # aws identitystore list-users --identity-store-id d-9a675288a4 --filters AttributePath=UserName,AttributeValue=pat
_persistent_membership_id = "818b75f0-60a1-700c-b5e4-dcfdd36616c8"  # aws identitystore list-group-memberships --identity-store-id d-9a675288a4 --group-id <group_id>

# AdminAccess permission set
_persistent_permission_set_name = "AdminAccess"
_persistent_permission_set_arn = "arn:aws:sso:::permissionSet/ssoins-668444b406cda8b2/ps-4751b925ba450440"  # aws sso-admin list-permission-sets --instance-arn arn:aws:sso:::instance/ssoins-668444b406cda8b2
_persistent_permission_set_external_name = _persistent_permission_set_arn + "," + _instance_arn if _persistent_permission_set_arn else ""

# =============================================================================
# Dynamic test resources - timestamped to allow concurrent test runs
# =============================================================================
_test_org_name = "hops-e2etest-ic"
_test_group_name = "E2ETestGroup-" + _now
_test_user_name = "e2e-test-user-" + _now
_test_permission_set_name = "E2ETest-" + _now

_items = [
    metav1alpha1.E2ETest{
        metadata.name: ""
        spec= {
            crossplane.autoUpgrade.channel: "Rapid"
            defaultConditions: ["Ready"]
            manifests: [
                hops.IdentityCenter{
                    metadata: {
                        name: _test_org_name
                        namespace: "default"
                    }
                    spec: {
                        organizationName: _test_org_name
                        managementPolicies: ["*"]
                        providerConfigRef: {
                            name: "default"
                        }
                        region: _region
                        identityStoreId: _identity_store_id
                        identityCenter: {
                            instanceArn: _instance_arn
                            sessionDuration: "PT2H"
                        }
                        groups: [
                            # Admins group - orphaned on cleanup
                            {
                                name: _persistent_group_name
                                displayName: "Admins"
                                if _persistent_group_id:
                                    externalName: _persistent_group_id
                                managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]
                            }
                            # Timestamped group - created and deleted each run
                            {
                                name: _test_group_name
                                displayName: _test_group_name
                            }
                        ]
                        users: [
                            # Pat - admin user, orphaned on cleanup
                            {
                                username: _persistent_user_name
                                email: "pat@ops.com.ai"
                                firstName: "Patrick Lee"
                                lastName: "Scott"
                                if _persistent_user_id:
                                    externalName: _persistent_user_id
                                managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]
                                groups: [_persistent_group_name]
                                if _persistent_membership_id:
                                    groupMembershipExternalNames: {(_persistent_group_name): _persistent_membership_id}
                            }
                            # Timestamped user - created and deleted each run
                            {
                                username: _test_user_name
                                email: "e2e-test-" + _now + "@ops.com.ai"
                                firstName: "E2E"
                                lastName: "Test"
                                groups: [_test_group_name]
                            }
                        ]
                        permissionSets: [
                            # AdminAccess - full admin, orphaned on cleanup
                            {
                                name: _persistent_permission_set_name
                                description: "Full administrator access"
                                if _persistent_permission_set_external_name:
                                    externalName: _persistent_permission_set_external_name
                                managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]
                                managedPolicies: [
                                    "arn:aws:iam::aws:policy/AdministratorAccess"
                                ]
                                assignToGroups: [_persistent_group_name]
                                assignToAccounts: [_target_account]
                            }
                            # Timestamped permission set - created and deleted each run
                            {
                                name: _test_permission_set_name
                                description: "Timestamped permission set for e2e validation"
                                managedPolicies: [
                                    "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
                                ]
                                assignToGroups: [_test_group_name]
                                assignToAccounts: [_target_account]
                            }
                        ]
                    }
                }
            ]
            extraResources: [
                {
                    apiVersion: "v1"
                    kind: "Secret"
                    metadata: {
                        name: "aws-creds"
                        namespace: "default"
                    }
                    data: {
                        creds: _base64_creds
                    }
                },
                {
                    apiVersion: "aws.m.upbound.io/v1beta1"
                    kind: "ProviderConfig"
                    metadata: {
                        name: "default"
                        namespace: "default"
                    }
                    spec: {
                        credentials: {
                            source: "Secret"
                            secretRef: {
                                namespace: "default"
                                name: "aws-creds"
                                key: "creds"
                            }
                        }
                    }
                }
            ]
            skipDelete: False
            timeoutSeconds: 5400
        }
    }
]
items= _items
