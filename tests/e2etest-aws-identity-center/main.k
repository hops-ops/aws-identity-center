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
_target_account = "123456789012"

# Persistent group - imported via externalName, not deleted on cleanup
_persistent_group_name = "hops-e2e-test"
# _persistent_group_id = "CHANGEME-group-id"

# Persistent user - imported via externalName, not deleted on cleanup
_persistent_user_name = "hops-e2e-admin"
# _persistent_user_id = "CHANGEME-user-id"

# Persistent permission set - imported via externalName, not deleted on cleanup
_persistent_permission_set_name = "E2EPersistentAccess"
# _persistent_permission_set_arn = "arn:aws:sso:::permissionSet/ssoins-CHANGEME/ps-CHANGEME"

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
                        managementMode: "self"
                        managementPolicies: ["*"]
                        providerConfigName: "default"
                        region: _region
                        identityStoreId: _identity_store_id
                        identityCenter: {
                            instanceArn: _instance_arn
                            sessionDuration: "PT2H"
                        }
                        groups: [
                            # Persistent group - imported and orphaned (won't be deleted)
                            {
                                name: _persistent_group_name
                                displayName: "E2E Persistent Admins"
                                externalName: _persistent_group_id
                                managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]
                            }
                            # Timestamped group - created and deleted each run
                            {
                                name: _test_group_name
                                displayName: "E2E Timestamped Test Group"
                            }
                        ]
                        users: [
                            # Persistent user - imported and orphaned (won't be deleted)
                            {
                                username: _persistent_user_name
                                email: "e2e-persistent-admin@ops.com.ai"
                                firstName: "E2E"
                                lastName: "Persistent"
                                # externalName: _persistent_user_id
                                managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]
                                groups: [_persistent_group_name]
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
                            # Persistent permission set - imported and orphaned
                            {
                                name: _persistent_permission_set_name
                                description: "Persistent permission set for e2e testing"
                                # externalName: _persistent_permission_set_arn
                                managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]
                                managedPolicies: [
                                    "arn:aws:iam::aws:policy/ReadOnlyAccess"
                                ]
                                assignToGroups: [_persistent_group_name]
                                assignToAccounts: [_target_account]
                            }
                            # Timestamped permission set - created and deleted each run
                            {
                                name: _test_permission_set_name
                                description: "Timestamped permission set for e2e validation"
                                managedPolicies: [
                                    "arn:aws:iam::aws:policy/ViewOnlyAccess"
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
