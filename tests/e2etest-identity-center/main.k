import base64
import datetime
import file
import math
import models.ai.com.ops.hops.aws.v1alpha1 as awsv1alpha1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

_now = str(int(math.floor(datetime.ticks())))
_test_name = "identity-center-" + _now
_provider_name = _test_name + "-provider"

# Update these identifiers to match the AWS Identity Center instance used for e2e.
_instance_arn = "arn:aws:sso:::instance/ssoins-CHANGE-ME"
_identity_store_id = "d-CHANGE-ME"
_target_account = "123456789012"

_creds = file.read("aws-creds")
_base64_creds = base64.encode(_creds)

_items = [
    metav1alpha1.E2ETest{
        metadata.name: ""
        spec = {
            crossplane.autoUpgrade.channel: "Rapid"
            defaultConditions: ["Ready"]
            manifests: [
                awsv1alpha1.IdentityCenter{
                    metadata: {
                        name: "e2etest-identity-center"
                        namespace: "default"
                    }
                    spec: {
                        organizationName: _test_name
                        managementMode: "self"
                        managementPolicies: ["*"]
                        providerConfigName: _provider_name
                        identityCenter: {
                            instanceArn: _instance_arn
                            sessionDuration: "PT2H"
                        }
                        identityStore: {
                            id: _identity_store_id
                        }
                        groups: [
                            {
                                name: "E2EAdmins"
                                displayName: "E2E Admins"
                            }
                        ]
                        users: [
                            {
                                username: "e2e-admin"
                                email: "e2e-admin@example.com"
                                firstName: "E2E"
                                lastName: "Admin"
                                groups: ["E2EAdmins"]
                            }
                        ]
                        permissionSets: [
                            {
                                name: "E2EAdministratorAccess"
                                description: "Full admin access for IdentityCenter e2e validation"
                                managedPolicies: [
                                    "arn:aws:iam::aws:policy/AdministratorAccess"
                                ]
                                assignToGroups: ["E2EAdmins"]
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
                        name: _provider_name
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
