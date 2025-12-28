#!/bin/bash
# Ticket 3: Setup IAM Roles for Lambda and Bedrock Agent
#
# Creates:
# - demo-cost-explorer-tool-role (for Lambda)
# - demo-cost-agent-role (for Bedrock Agent)

set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

echo "=========================================="
echo "IAM Roles Setup"
echo "=========================================="
echo "Account:  $AWS_ACCOUNT_ID"
echo "Region:   $AWS_REGION"
echo ""

# Directory containing policy files
POLICY_DIR="$SCRIPT_DIR/../infrastructure/iam-policies"

# ==========================================
# Lambda Execution Role
# ==========================================
echo "[1/2] Creating Lambda execution role: $LAMBDA_ROLE_NAME"

# Check if role already exists
if aws iam get-role --role-name "$LAMBDA_ROLE_NAME" 2>/dev/null; then
    echo "  Role already exists, skipping creation."
else
    # Create the role with trust policy
    aws iam create-role \
        --role-name "$LAMBDA_ROLE_NAME" \
        --assume-role-policy-document file://"$POLICY_DIR/lambda-trust-policy.json" \
        --description "Execution role for demo-cost-explorer-tool Lambda"

    echo "  Role created."
fi

# Attach permissions policy
echo "  Attaching permissions policy..."
aws iam put-role-policy \
    --role-name "$LAMBDA_ROLE_NAME" \
    --policy-name "CostExplorerAccess" \
    --policy-document file://"$POLICY_DIR/lambda-permissions-policy.json"

echo "  Done."
echo ""

# ==========================================
# Agent Execution Role
# ==========================================
echo "[2/2] Creating Agent execution role: $AGENT_ROLE_NAME"

# Check if role already exists
if aws iam get-role --role-name "$AGENT_ROLE_NAME" 2>/dev/null; then
    echo "  Role already exists, skipping creation."
else
    # Create the role with trust policy
    aws iam create-role \
        --role-name "$AGENT_ROLE_NAME" \
        --assume-role-policy-document file://"$POLICY_DIR/agent-trust-policy.json" \
        --description "Execution role for demo-cost-explainer-agent Bedrock Agent"

    echo "  Role created."
fi

# Generate agent permissions policy with substituted variables
echo "  Generating permissions policy with account-specific values..."
AGENT_POLICY=$(cat "$POLICY_DIR/agent-permissions-policy.json" | \
    sed "s/\${AWS_REGION}/$AWS_REGION/g" | \
    sed "s/\${AWS_ACCOUNT_ID}/$AWS_ACCOUNT_ID/g" | \
    sed "s/\${LAMBDA_FUNCTION_NAME}/$LAMBDA_FUNCTION_NAME/g")

# Attach permissions policy
echo "  Attaching permissions policy..."
aws iam put-role-policy \
    --role-name "$AGENT_ROLE_NAME" \
    --policy-name "AgentAccess" \
    --policy-document "$AGENT_POLICY"

echo "  Done."
echo ""

# ==========================================
# Verification
# ==========================================
echo "=========================================="
echo "Verification"
echo "=========================================="

echo ""
echo "Lambda Role ARN:"
aws iam get-role --role-name "$LAMBDA_ROLE_NAME" --query 'Role.Arn' --output text

echo ""
echo "Agent Role ARN:"
aws iam get-role --role-name "$AGENT_ROLE_NAME" --query 'Role.Arn' --output text

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next: Run Ticket 4 to implement the Lambda function."
