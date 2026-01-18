#!/bin/bash
# get-external-names.sh - Extract AWS Identity Center resource IDs for import
# Usage: ./scripts/get-external-names.sh [identity-store-id] [instance-arn] [region]
#
# Queries AWS for all Identity Center resources and outputs
# the external names in KCL format ready for the e2e test.

set -euo pipefail

# Defaults from e2e test
IDENTITY_STORE_ID="${1:-d-9a675288a4}"
INSTANCE_ARN="${2:-arn:aws:sso:::instance/ssoins-668444b406cda8b2}"
REGION="${3:-us-east-2}"

echo "# Fetching AWS Identity Center resources"
echo "# Identity Store ID: $IDENTITY_STORE_ID"
echo "# Instance ARN: $INSTANCE_ARN"
echo "# Region: $REGION"
echo ""

# =============================================================================
# Groups
# =============================================================================
echo "# Groups"
echo "# aws identitystore list-groups --identity-store-id $IDENTITY_STORE_ID"

aws identitystore list-groups \
    --identity-store-id "$IDENTITY_STORE_ID" \
    --region "$REGION" \
    --query 'Groups[*].[DisplayName, GroupId]' \
    --output text 2>/dev/null | while read -r name id; do
    if [[ -n "$name" && -n "$id" ]]; then
        # Sanitize name for KCL variable
        var_name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
        echo "_${var_name}_group_id = \"$id\"  # $name"
    fi
done

echo ""

# =============================================================================
# Users
# =============================================================================
echo "# Users"
echo "# aws identitystore list-users --identity-store-id $IDENTITY_STORE_ID"

aws identitystore list-users \
    --identity-store-id "$IDENTITY_STORE_ID" \
    --region "$REGION" \
    --query 'Users[*].[UserName, UserId]' \
    --output text 2>/dev/null | while read -r username id; do
    if [[ -n "$username" && -n "$id" ]]; then
        var_name=$(echo "$username" | tr '[:upper:]' '[:lower:]' | tr ' -@.' '_')
        echo "_${var_name}_user_id = \"$id\"  # $username"
    fi
done

echo ""

# =============================================================================
# Group Memberships
# =============================================================================
echo "# Group Memberships"
echo "# For each group, list memberships"

# Get all groups first
groups_json=$(aws identitystore list-groups \
    --identity-store-id "$IDENTITY_STORE_ID" \
    --region "$REGION" \
    --output json 2>/dev/null)

echo "$groups_json" | jq -r '.Groups[] | "\(.GroupId) \(.DisplayName)"' 2>/dev/null | while read -r group_id group_name; do
    if [[ -n "$group_id" && "$group_id" != "null" ]]; then
        # List memberships for this group
        memberships=$(aws identitystore list-group-memberships \
            --identity-store-id "$IDENTITY_STORE_ID" \
            --group-id "$group_id" \
            --region "$REGION" \
            --output json 2>/dev/null)

        echo "$memberships" | jq -r '.GroupMemberships[] | "\(.MembershipId) \(.MemberId.UserId)"' 2>/dev/null | while read -r membership_id user_id; do
            if [[ -n "$membership_id" && "$membership_id" != "null" ]]; then
                # Get username for this user
                username=$(aws identitystore describe-user \
                    --identity-store-id "$IDENTITY_STORE_ID" \
                    --user-id "$user_id" \
                    --region "$REGION" \
                    --query 'UserName' \
                    --output text 2>/dev/null || echo "unknown")

                var_user=$(echo "$username" | tr '[:upper:]' '[:lower:]' | tr ' -@.' '_')
                var_group=$(echo "$group_name" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
                echo "_${var_user}_${var_group}_membership_id = \"$membership_id\"  # $username in $group_name"
            fi
        done
    fi
done

echo ""

# =============================================================================
# Permission Sets
# =============================================================================
echo "# Permission Sets"
echo "# aws sso-admin list-permission-sets --instance-arn $INSTANCE_ARN"

permission_sets=$(aws sso-admin list-permission-sets \
    --instance-arn "$INSTANCE_ARN" \
    --region "$REGION" \
    --output json 2>/dev/null)

echo "$permission_sets" | jq -r '.PermissionSets[]' 2>/dev/null | while read -r ps_arn; do
    if [[ -n "$ps_arn" && "$ps_arn" != "null" ]]; then
        # Get permission set details
        ps_details=$(aws sso-admin describe-permission-set \
            --instance-arn "$INSTANCE_ARN" \
            --permission-set-arn "$ps_arn" \
            --region "$REGION" \
            --output json 2>/dev/null)

        ps_name=$(echo "$ps_details" | jq -r '.PermissionSet.Name')
        var_name=$(echo "$ps_name" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')

        # External name format: PERMISSION_SET_ARN,INSTANCE_ARN
        external_name="${ps_arn},${INSTANCE_ARN}"
        echo "_${var_name}_permission_set_arn = \"$ps_arn\"  # $ps_name"
        echo "_${var_name}_permission_set_external_name = \"$external_name\""
    fi
done

echo ""

# =============================================================================
# Account Assignments
# =============================================================================
echo "# Account Assignments"
echo "# Listing assignments for each permission set..."

echo "$permission_sets" | jq -r '.PermissionSets[]' 2>/dev/null | while read -r ps_arn; do
    if [[ -n "$ps_arn" && "$ps_arn" != "null" ]]; then
        ps_details=$(aws sso-admin describe-permission-set \
            --instance-arn "$INSTANCE_ARN" \
            --permission-set-arn "$ps_arn" \
            --region "$REGION" \
            --output json 2>/dev/null)
        ps_name=$(echo "$ps_details" | jq -r '.PermissionSet.Name')

        # List accounts provisioned with this permission set
        accounts=$(aws sso-admin list-accounts-for-provisioned-permission-set \
            --instance-arn "$INSTANCE_ARN" \
            --permission-set-arn "$ps_arn" \
            --region "$REGION" \
            --output json 2>/dev/null || echo '{"AccountIds":[]}')

        echo "$accounts" | jq -r '.AccountIds[]' 2>/dev/null | while read -r account_id; do
            if [[ -n "$account_id" && "$account_id" != "null" ]]; then
                # List assignments for this account/permission set
                assignments=$(aws sso-admin list-account-assignments \
                    --instance-arn "$INSTANCE_ARN" \
                    --permission-set-arn "$ps_arn" \
                    --account-id "$account_id" \
                    --region "$REGION" \
                    --output json 2>/dev/null)

                echo "$assignments" | jq -r '.AccountAssignments[] | "\(.PrincipalType) \(.PrincipalId)"' 2>/dev/null | while read -r principal_type principal_id; do
                    if [[ -n "$principal_id" && "$principal_id" != "null" ]]; then
                        # Get principal name
                        if [[ "$principal_type" == "GROUP" ]]; then
                            principal_name=$(aws identitystore describe-group \
                                --identity-store-id "$IDENTITY_STORE_ID" \
                                --group-id "$principal_id" \
                                --region "$REGION" \
                                --query 'DisplayName' \
                                --output text 2>/dev/null || echo "unknown")
                        else
                            principal_name=$(aws identitystore describe-user \
                                --identity-store-id "$IDENTITY_STORE_ID" \
                                --user-id "$principal_id" \
                                --region "$REGION" \
                                --query 'UserName' \
                                --output text 2>/dev/null || echo "unknown")
                        fi

                        var_ps=$(echo "$ps_name" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
                        var_principal=$(echo "$principal_name" | tr '[:upper:]' '[:lower:]' | tr ' -@.' '_')

                        # External name format: PRINCIPAL_ID,PRINCIPAL_TYPE,PERMISSION_SET_ARN,ACCOUNT_ID,INSTANCE_ARN
                        external_name="${principal_id},${principal_type},${ps_arn},${account_id},${INSTANCE_ARN}"
                        echo "# ${ps_name} -> ${principal_name} (${principal_type}) on account ${account_id}"
                        echo "_${var_ps}_${var_principal}_${account_id}_assignment_external_name = \"$external_name\""
                    fi
                done
            fi
        done
    fi
done

echo ""

# =============================================================================
# Managed Policy Attachments
# =============================================================================
echo "# Managed Policy Attachments"

echo "$permission_sets" | jq -r '.PermissionSets[]' 2>/dev/null | while read -r ps_arn; do
    if [[ -n "$ps_arn" && "$ps_arn" != "null" ]]; then
        ps_details=$(aws sso-admin describe-permission-set \
            --instance-arn "$INSTANCE_ARN" \
            --permission-set-arn "$ps_arn" \
            --region "$REGION" \
            --output json 2>/dev/null)
        ps_name=$(echo "$ps_details" | jq -r '.PermissionSet.Name')

        policies=$(aws sso-admin list-managed-policies-in-permission-set \
            --instance-arn "$INSTANCE_ARN" \
            --permission-set-arn "$ps_arn" \
            --region "$REGION" \
            --output json 2>/dev/null || echo '{"AttachedManagedPolicies":[]}')

        echo "$policies" | jq -r '.AttachedManagedPolicies[] | .Arn' 2>/dev/null | while read -r policy_arn; do
            if [[ -n "$policy_arn" && "$policy_arn" != "null" ]]; then
                policy_name=$(basename "$policy_arn")
                var_ps=$(echo "$ps_name" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
                var_policy=$(echo "$policy_name" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')

                # External name format: MANAGED_POLICY_ARN,PERMISSION_SET_ARN,INSTANCE_ARN
                external_name="${policy_arn},${ps_arn},${INSTANCE_ARN}"
                echo "# ${ps_name} <- ${policy_name}"
                echo "_${var_ps}_${var_policy}_managed_policy_external_name = \"$external_name\""
            fi
        done
    fi
done

echo ""
echo "# Done! Copy the relevant values into your e2e test file."
