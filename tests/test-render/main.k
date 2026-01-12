
import models.ai.com.ops.hops.aws.v1alpha1 as awsv1alpha1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.dev.meta.v2alpha1 as metav2alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

# =============================================================================
# Test: Default values - organizationName defaults to metadata.name
# =============================================================================
_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "defaults-organization-name-from-metadata"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            # Inline fixture: no organizationName specified, should use metadata.name
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "IdentityCenter"
                metadata.name: "my-org-sso"
                spec: {
                    managementPolicies: ["*"]
                    region: "us-east-1"
                    identityStoreId: "d-test123"
                    identityCenter.instanceArn: "arn:aws:sso:::instance/ssoins-test"
                    groups: [{name: "TestGroup"}]
                }
            }
            assertResources: [
                # Group name should use metadata.name (my-org-sso) as organization prefix
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "Group"
                    metadata.name: "my-org-sso-ic-group-testgroup"
                    spec.forProvider.displayName: "TestGroup"
                }
            ]
        }
    },

    # =============================================================================
    # Test: organizationName overrides metadata.name
    # =============================================================================
    metav1alpha1.CompositionTest{
        metadata.name: "organization-name-override"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "IdentityCenter"
                metadata.name: "my-org-sso"
                spec: {
                    organizationName: "custom-org"
                    managementPolicies: ["*"]
                    region: "us-east-1"
                    identityStoreId: "d-test123"
                    identityCenter.instanceArn: "arn:aws:sso:::instance/ssoins-test"
                    groups: [{name: "TestGroup"}]
                }
            }
            assertResources: [
                # Group name should use organizationName (custom-org) as prefix
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "Group"
                    metadata.name: "custom-org-ic-group-testgroup"
                    spec.forProvider.displayName: "TestGroup"
                }
            ]
        }
    },

    # =============================================================================
    # Test: No users scenario - only groups and permission sets render
    # =============================================================================
    metav1alpha1.CompositionTest{
        metadata.name: "no-users-only-groups"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "IdentityCenter"
                metadata.name: "no-users-test"
                spec: {
                    managementPolicies: ["*"]
                    region: "us-east-1"
                    identityStoreId: "d-123456"
                    identityCenter.instanceArn: "arn:aws:sso:::instance/ssoins-123"
                    # No users array - should still work
                    groups: [{name: "TestGroup", displayName: "Test Group"}]
                    permissionSets: [{
                        name: "ViewerAccess"
                        managedPolicies: ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
                        assignToGroups: ["TestGroup"]
                        assignToAccounts: ["123456789012"]
                    }]
                }
            }
            assertResources: [
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "Group"
                    metadata.name: "no-users-test-ic-group-testgroup"
                },
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSet"
                    metadata.name: "no-users-test-vieweraccess"
                },
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "AccountAssignment"
                    metadata.name: "no-users-test-vieweraccess-assign-123456789012-group-testgroup"
                    spec.forProvider.principalType: "GROUP"
                }
            ]
        }
    },

    # =============================================================================
    # Test: Management policies override at resource level
    # =============================================================================
    metav1alpha1.CompositionTest{
        metadata.name: "management-policies-override"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "IdentityCenter"
                metadata.name: "mgmt-policy-test"
                spec: {
                    managementPolicies: ["*"]  # Default for all resources
                    region: "us-east-1"
                    identityStoreId: "d-test"
                    identityCenter.instanceArn: "arn:aws:sso:::instance/ssoins-test"
                    groups: [
                        {name: "FullManaged"},  # Should inherit ["*"]
                        {
                            name: "Orphaned"
                            managementPolicies: ["Observe"]  # Override to orphan
                        }
                    ]
                }
            }
            assertResources: [
                # FullManaged group inherits default managementPolicies
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "Group"
                    metadata.name: "mgmt-policy-test-ic-group-fullmanaged"
                    spec.managementPolicies: ["*"]
                },
                # Orphaned group uses overridden managementPolicies
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "Group"
                    metadata.name: "mgmt-policy-test-ic-group-orphaned"
                    spec.managementPolicies: ["Observe"]
                }
            ]
        }
    },

    # =============================================================================
    # Test: External name annotation for importing existing resources
    # Uses inline externalName fields on each item
    # =============================================================================
    metav1alpha1.CompositionTest{
        metadata.name: "external-name-import"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "IdentityCenter"
                metadata.name: "import-test"
                spec: {
                    managementPolicies: ["*"]
                    region: "us-east-1"
                    identityStoreId: "d-test"
                    identityCenter.instanceArn: "arn:aws:sso:::instance/ssoins-test"
                    groups: [{
                        name: "ExistingGroup"
                        externalName: "94815e08-1234-5678-9abc-def012345678"
                    }]
                    users: [{
                        username: "existing-user"
                        email: "existing@example.com"
                        externalName: "84815e08-abcd-1234-5678-901234567890"
                    }]
                    permissionSets: [{
                        name: "ExistingPS"
                        externalName: "arn:aws:sso:::permissionSet/ssoins-test/ps-existing,arn:aws:sso:::instance/ssoins-test"
                    }]
                }
            }
            assertResources: [
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "Group"
                    metadata: {
                        name: "import-test-ic-group-existinggroup"
                        annotations: {
                            "crossplane.io/external-name": "94815e08-1234-5678-9abc-def012345678"
                        }
                    }
                },
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "User"
                    metadata: {
                        name: "import-test-ic-user-existing-user"
                        annotations: {
                            "crossplane.io/external-name": "84815e08-abcd-1234-5678-901234567890"
                        }
                    }
                },
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSet"
                    metadata: {
                        name: "import-test-existingps"
                        annotations: {
                            "crossplane.io/external-name": "arn:aws:sso:::permissionSet/ssoins-test/ps-existing,arn:aws:sso:::instance/ssoins-test"
                        }
                    }
                }
            ]
        }
    },

    # =============================================================================
    # Test: Session duration defaults to PT1H
    # =============================================================================
    metav1alpha1.CompositionTest{
        metadata.name: "session-duration-default"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "IdentityCenter"
                metadata.name: "session-test"
                spec: {
                    managementPolicies: ["*"]
                    region: "us-east-1"
                    identityStoreId: "d-test"
                    identityCenter.instanceArn: "arn:aws:sso:::instance/ssoins-test"
                    # No sessionDuration specified - should default to PT1H
                    permissionSets: [{name: "TestPS"}]
                }
            }
            assertResources: [
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSet"
                    metadata.name: "session-test-testps"
                    spec.forProvider.sessionDuration: "PT1H"
                }
            ]
        }
    },

    # =============================================================================
    # Test: Custom session duration override
    # =============================================================================
    metav1alpha1.CompositionTest{
        metadata.name: "session-duration-override"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "IdentityCenter"
                metadata.name: "session-override"
                spec: {
                    managementPolicies: ["*"]
                    region: "us-east-1"
                    identityStoreId: "d-test"
                    identityCenter: {
                        instanceArn: "arn:aws:sso:::instance/ssoins-test"
                        sessionDuration: "PT4H"  # Override to 4 hours
                    }
                    permissionSets: [{name: "LongSession"}]
                }
            }
            assertResources: [
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSet"
                    metadata.name: "session-override-longsession"
                    spec.forProvider.sessionDuration: "PT4H"
                }
            ]
        }
    },

    # =============================================================================
    # Test: Default AWS tags merged onto permission sets
    # =============================================================================
    metav1alpha1.CompositionTest{
        metadata.name: "default-tags-merged"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "IdentityCenter"
                metadata.name: "tags-test"
                spec: {
                    managementPolicies: ["*"]
                    region: "us-east-1"
                    identityStoreId: "d-test"
                    identityCenter: {
                        instanceArn: "arn:aws:sso:::instance/ssoins-test"
                        tags: {environment: "production"}
                    }
                    permissionSets: [{name: "TaggedPS"}]
                }
            }
            assertResources: [
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSet"
                    metadata.name: "tags-test-taggedps"
                    spec.forProvider.tags: {
                        "hops.ops.com.ai/managed": "true"
                        "hops.ops.com.ai/identitycenter": "tags-test"
                        environment: "production"
                    }
                }
            ]
        }
    },

    # =============================================================================
    # Test: Inline policy renders PermissionSetInlinePolicy resource
    # =============================================================================
    metav1alpha1.CompositionTest{
        metadata.name: "inline-policy-renders"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "IdentityCenter"
                metadata.name: "inline-test"
                spec: {
                    managementPolicies: ["*"]
                    region: "us-east-1"
                    identityStoreId: "d-test"
                    identityCenter.instanceArn: "arn:aws:sso:::instance/ssoins-test"
                    permissionSets: [{
                        name: "WithInline"
                        inlinePolicy: '{"Version": "2012-10-17", "Statement": []}'
                    }]
                }
            }
            # Note: We only verify resources exist; render/validate checks schema validity
            # Inline policy is output as a YAML literal block which adds trailing newline
            assertResources: [
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSet"
                    metadata.name: "inline-test-withinline"
                },
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSetInlinePolicy"
                    metadata.name: "inline-test-withinline-inline"
                    spec.forProvider.permissionSetArnRef.name: "inline-test-withinline"
                }
            ]
        }
    },

    # =============================================================================
    # Test: Customer managed policy attachment
    # =============================================================================
    metav1alpha1.CompositionTest{
        metadata.name: "customer-managed-policy"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "IdentityCenter"
                metadata.name: "customer-policy-test"
                spec: {
                    managementPolicies: ["*"]
                    region: "us-east-1"
                    identityStoreId: "d-test"
                    identityCenter.instanceArn: "arn:aws:sso:::instance/ssoins-test"
                    permissionSets: [{
                        name: "WithCustomPolicy"
                        customerManagedPolicies: [{name: "MyPolicy", path: "/custom/"}]
                    }]
                }
            }
            assertResources: [
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "CustomerManagedPolicyAttachment"
                    metadata.name: "customer-policy-test-withcustompolicy-customer-mypolicy"
                    spec.forProvider.customerManagedPolicyReference: {
                        name: "MyPolicy"
                        path: "/custom/"
                    }
                }
            ]
        }
    },

    # =============================================================================
    # Test: User with group membership renders GroupMembership resource
    # =============================================================================
    metav1alpha1.CompositionTest{
        metadata.name: "user-group-membership"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "IdentityCenter"
                metadata.name: "membership-test"
                spec: {
                    managementPolicies: ["*"]
                    region: "us-east-1"
                    identityStoreId: "d-test"
                    identityCenter.instanceArn: "arn:aws:sso:::instance/ssoins-test"
                    groups: [{name: "Developers"}]
                    users: [{
                        username: "dev-user"
                        email: "dev@example.com"
                        groups: ["Developers"]
                    }]
                }
            }
            assertResources: [
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "User"
                    metadata.name: "membership-test-ic-user-dev-user"
                },
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "Group"
                    metadata.name: "membership-test-ic-group-developers"
                },
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "GroupMembership"
                    metadata.name: "membership-test-ic-membership-dev-user-developers"
                    spec.forProvider: {
                        memberIdRef.name: "membership-test-ic-user-dev-user"
                        groupIdRef.name: "membership-test-ic-group-developers"
                    }
                }
            ]
        }
    },

    # =============================================================================
    # Test: Explicit assignment with principal.id (direct ID reference)
    # =============================================================================
    metav1alpha1.CompositionTest{
        metadata.name: "explicit-assignment-principal-id"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "IdentityCenter"
                metadata.name: "explicit-id-test"
                spec: {
                    managementPolicies: ["*"]
                    region: "us-east-1"
                    identityStoreId: "d-test"
                    identityCenter.instanceArn: "arn:aws:sso:::instance/ssoins-test"
                    permissionSets: [{
                        name: "DirectAssign"
                        assignments: [{
                            accountId: "111111111111"
                            principal: {
                                type: "GROUP"
                                id: "existing-group-id-12345"
                            }
                        }]
                    }]
                }
            }
            assertResources: [
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "AccountAssignment"
                    metadata.name: "explicit-id-test-directassign-assign-111111111111-group-existing-group-id-12345"
                    spec.forProvider: {
                        principalType: "GROUP"
                        principalId: "existing-group-id-12345"
                        targetId: "111111111111"
                    }
                }
            ]
        }
    },

    # =============================================================================
    # Test: Observed resources flow into template state
    # Note: Status is patched onto XR, verified via make validate:all --include-full-xr
    # This test verifies observed resources are available for gated rendering
    # =============================================================================
    metav1alpha1.CompositionTest{
        metadata.name: "observed-resources-available"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "IdentityCenter"
                metadata.name: "observed-test"
                spec: {
                    managementPolicies: ["*"]
                    region: "us-east-1"
                    identityStoreId: "d-observed123"
                    identityCenter.instanceArn: "arn:aws:sso:::instance/ssoins-observed"
                    groups: [{name: "ObservedGroup"}]
                    permissionSets: [{
                        name: "ObservedPS"
                        managedPolicies: ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
                    }]
                }
            }
            # Simulate permission set observed and ready - Usage resources gate on this
            observedResources: [
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSet"
                    metadata: {
                        name: "observed-test-observedps"
                        annotations: {"crossplane.io/composition-resource-name": "permission-set-ObservedPS"}
                    }
                    status: {
                        conditions: [{type: "Ready", status: "True"}, {type: "Synced", status: "True"}]
                        atProvider: {arn: "arn:aws:sso:::permissionSet/ssoins-observed/ps-123"}
                    }
                },
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "ManagedPolicyAttachment"
                    metadata: {
                        name: "observed-test-observedps-managed-readonlyaccess"
                        annotations: {"crossplane.io/composition-resource-name": "permission-set-managed-policy-ObservedPS-readonlyaccess"}
                    }
                    status: {
                        conditions: [{type: "Ready", status: "True"}, {type: "Synced", status: "True"}]
                        atProvider: {}
                    }
                }
            ]
            # When PermissionSet and ManagedPolicyAttachment are Ready, Usage is created
            assertResources: [
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "PermissionSet"
                    metadata.name: "observed-test-observedps"
                },
                {
                    apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                    kind: "ManagedPolicyAttachment"
                    metadata.name: "observed-test-observedps-managed-readonlyaccess"
                },
                # Usage resource only renders when both PS and ManagedPolicy are Ready
                {
                    apiVersion: "protection.crossplane.io/v1beta1"
                    kind: "Usage"
                    metadata.name: "of-observed-test-observedps-by-observed-test-observedps-managed-readonlyaccess"
                    spec: {
                        replayDeletion: True
                        of: {
                            apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                            kind: "PermissionSet"
                            resourceRef.name: "observed-test-observedps"
                        }
                        by: {
                            apiVersion: "ssoadmin.aws.m.upbound.io/v1beta1"
                            kind: "ManagedPolicyAttachment"
                            resourceRef.name: "observed-test-observedps-managed-readonlyaccess"
                        }
                    }
                }
            ]
        }
    },

    # =============================================================================
    # Test: User display name computation (firstName + lastName)
    # =============================================================================
    metav1alpha1.CompositionTest{
        metadata.name: "user-display-name-from-names"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "IdentityCenter"
                metadata.name: "display-test"
                spec: {
                    managementPolicies: ["*"]
                    region: "us-east-1"
                    identityStoreId: "d-test"
                    identityCenter.instanceArn: "arn:aws:sso:::instance/ssoins-test"
                    users: [{
                        username: "john.doe"
                        email: "john@example.com"
                        firstName: "John"
                        lastName: "Doe"
                        # No displayName - should compute from firstName + lastName
                    }]
                }
            }
            assertResources: [
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "User"
                    metadata.name: "display-test-ic-user-john-doe"
                    spec.forProvider: {
                        displayName: "John Doe"
                        name: {
                            givenName: "John"
                            familyName: "Doe"
                        }
                    }
                }
            ]
        }
    },

    # =============================================================================
    # Test: User explicit displayName overrides computed
    # =============================================================================
    metav1alpha1.CompositionTest{
        metadata.name: "user-explicit-display-name"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "IdentityCenter"
                metadata.name: "explicit-display-test"
                spec: {
                    managementPolicies: ["*"]
                    region: "us-east-1"
                    identityStoreId: "d-test"
                    identityCenter.instanceArn: "arn:aws:sso:::instance/ssoins-test"
                    users: [{
                        username: "jdoe"
                        email: "john@example.com"
                        firstName: "John"
                        lastName: "Doe"
                        displayName: "Johnny D"  # Explicit override
                    }]
                }
            }
            assertResources: [
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "User"
                    metadata.name: "explicit-display-test-ic-user-jdoe"
                    spec.forProvider.displayName: "Johnny D"
                }
            ]
        }
    },

    # =============================================================================
    # Test: providerConfigRef defaults to organizationName
    # =============================================================================
    metav1alpha1.CompositionTest{
        metadata.name: "provider-config-defaults"
        spec = {
            compositionPath: "apis/identitycenters/composition.yaml"
            xrdPath: "apis/identitycenters/definition.yaml"
            timeoutSeconds: 120
            validate: True
            xr: {
                apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                kind: "IdentityCenter"
                metadata.name: "provider-default-test"
                spec: {
                    organizationName: "my-custom-org"
                    managementPolicies: ["*"]
                    region: "us-east-1"
                    identityStoreId: "d-test"
                    identityCenter.instanceArn: "arn:aws:sso:::instance/ssoins-test"
                    # No providerConfigRef - should default to organizationName
                    groups: [{name: "TestGroup"}]
                }
            }
            assertResources: [
                {
                    apiVersion: "identitystore.aws.m.upbound.io/v1beta1"
                    kind: "Group"
                    metadata.name: "my-custom-org-ic-group-testgroup"
                    spec.providerConfigRef: {
                        name: "my-custom-org"
                        kind: "ProviderConfig"
                    }
                }
            ]
        }
    }
]

items = _items
