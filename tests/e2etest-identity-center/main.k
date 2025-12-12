import base64
import datetime
import file
import math
import models.ai.com.ops.hops.aws.v1alpha1 as awsv1alpha1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

_now = str(int(math.floor(datetime.ticks())))

_creds = file.read("secrets/aws-creds")
_base64_creds = base64.encode(_creds)

# =============================================================================
# Identity Center instance - AWS only allows one per organization
# Get these values from AWS Console or CLI:
#   aws sso-admin list-instances
# =============================================================================
_instance_arn = "arn:aws:sso:::instance/ssoins-CHANGE-ME"
_identity_store_id = "d-CHANGE-ME"
_target_account = "123456789012"  # Account to test assignments against
_region = "us-east-1"

# =============================================================================
# Dynamic test resources - timestamped to allow concurrent test runs
# =============================================================================
_test_org_name = "hops-e2etest-ic-" + _now
_test_group_name = "E2ETestGroup-" + _now
_test_user_name = "e2e-test-user-" + _now
_test_permission_set_name = "E2ETest-" + _now

_items = [
    metav1alpha1.E2ETest{
        metadata.name: ""
        spec = {
            crossplane.autoUpgrade.channel: "Rapid"
            defaultConditions: ["Ready"]
            manifests: [
                awsv1alpha1.IdentityCenter{
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
                        identityCenter: {
                            instanceArn: _instance_arn
                            sessionDuration: "PT2H"
                        }
                        identityStore: {
                            id: _identity_store_id
                        }
                        groups: [
                            {
                                name: _test_group_name
                                displayName: "E2E Test Group " + _now
                            }
                        ]
                        users: [
                            {
                                username: _test_user_name
                                email: "e2e-test-" + _now + "@ops.com.ai"
                                firstName: "E2E"
                                lastName: "Test"
                                groups: [_test_group_name]
                            }
                        ]
                        permissionSets: [
                            {
                                name: _test_permission_set_name
                                description: "E2E test permission set - " + _now
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
items = _items
