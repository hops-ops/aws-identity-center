
import models.ai.com.ops.hops.aws.v1alpha1 as awsv1alpha1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.dev.meta.v2alpha1 as metav2alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

_inline_policy = "{\n  \"Version\": \"2012-10-17\",\n  \"Statement\": [\n    {\n      \"Effect\": \"Allow\",\n      \"Action\": [\n        \"ec2:Describe*\"\n      ],\n      \"Resource\": \"*\"\n    }\n  ]\n}\n"

_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-identity-center-minimal"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrPath: "examples/identitycenters/minimal.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            assertResources: [
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "Group"
                    metadata: {
                        name: "platform-sso-ic-group-admins"
                    }
                    spec: {
                        forProvider: {
                            identityStoreId: "d-1234567890"
                            displayName: "Platform Admins"
                        }
                    }
                },
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "User"
                    metadata: {
                        name: "platform-sso-ic-user-platform-admin"
                        labels: {
                            'aws.hops.ops.com.ai/identity-center-user': "platform-admin"
                        }
                    }
                    spec: {
                        managementPolicies: ["*"]
                        forProvider: {
                            identityStoreId: "d-1234567890"
                            displayName: "Platform Admin"
                            userName: "platform-admin"
                            emails: {
                                value: "platform-admin@example.com"
                                type: "work"
                                primary: True
                            }
                            name: {
                                givenName: "Platform"
                                familyName: "Admin"
                            }
                        }
                    }
                },
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "GroupMembership"
                    metadata: {
                        name: "platform-sso-ic-membership-platform-admin-admins"
                    }
                    spec: {
                        forProvider: {
                            identityStoreId: "d-1234567890"
                            memberIdRef: {
                                name: "platform-sso-ic-user-platform-admin"
                            }
                            groupIdRef: {
                                name: "platform-sso-ic-group-admins"
                            }
                        }
                    }
                },
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSet"
                    metadata: {
                        name: "platform-sso-adminaccess"
                        labels: {
                            'aws.hops.ops.com.ai/identity-center-permission-set': "adminaccess"
                        }
                    }
                    spec: {
                        forProvider: {
                            name: "AdminAccess"
                            instanceArn: "arn:aws:sso:::instance/ssoins-1234567890abcdef"
                            sessionDuration: "PT2H"
                            tags: {
                                hops: "true"
                                organization: "platform-sso"
                            }
                        }
                    }
                },
                # ManagedPolicyAttachment uses deterministic slug from policy ARN
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "ManagedPolicyAttachment"
                    metadata: {
                        name: "platform-sso-adminaccess-managed-administratoraccess"
                    }
                    spec: {
                        forProvider: {
                            managedPolicyArn: "arn:aws:iam::aws:policy/AdministratorAccess"
                            permissionSetArnRef: {
                                name: "platform-sso-adminaccess"
                            }
                        }
                    }
                },
                # AccountAssignment uses deterministic slug: accountId-principalType-principalName
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "AccountAssignment"
                    metadata: {
                        name: "platform-sso-adminaccess-assign-123456789012-group-admins"
                    }
                    spec: {
                        forProvider: {
                            permissionSetArnRef: {
                                name: "platform-sso-adminaccess"
                            }
                            targetId: "123456789012"
                            principalType: "GROUP"
                            principalIdFromGroupRef: {
                                name: "platform-sso-ic-group-admins"
                            }
                        }
                    }
                }
            ]
        }
    },
    metav1alpha1.CompositionTest{
        metadata.name: "test-identity-center-inline-policy"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrPath: "examples/identitycenters/groups.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            assertResources: [
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "Group"
                    metadata: {
                        name: "workloads-ic-group-workloadsengineering"
                    }
                    spec: {
                        forProvider: {
                            identityStoreId: "d-0987654321"
                            displayName: "Workloads Engineering"
                        }
                    }
                },
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSetInlinePolicy"
                    metadata: {
                        name: "workloads-workloads-readonly-inline"
                    }
                    spec: {
                        forProvider: {
                            inlinePolicy: _inline_policy
                        }
                    }
                },
                # CustomerManagedPolicyAttachment uses deterministic slug from policy name
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "CustomerManagedPolicyAttachment"
                    metadata: {
                        name: "workloads-workloads-readonly-customer-customaudit"
                    }
                    spec: {
                        forProvider: {
                            customerManagedPolicyReference: {
                                name: "CustomAudit"
                                path: "/auditors/"
                            }
                        }
                    }
                },
                # AccountAssignment for group assignment (from assignToGroups)
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "AccountAssignment"
                    metadata: {
                        name: "workloads-workloads-readonly-assign-210987654321-group-workloadsengineering"
                    }
                    spec: {
                        forProvider: {
                            principalType: "GROUP"
                            targetId: "210987654321"
                        }
                    }
                },
                # AccountAssignment for explicit user assignment
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "AccountAssignment"
                    metadata: {
                        name: "workloads-workloads-readonly-assign-999999999999-user-workloads-reader"
                    }
                    spec: {
                        forProvider: {
                            principalType: "USER"
                            targetId: "999999999999"
                        }
                    }
                }
            ]
        }
    }
]
items = _items
