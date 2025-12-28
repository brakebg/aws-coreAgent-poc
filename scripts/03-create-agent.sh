#!/bin/bash
# Ticket 7: Create Bedrock Agent and Bind Lambda Tool
#
# This script:
# 1. Creates the Bedrock Agent
# 2. Creates Action Group with Lambda binding
# 3. Prepares the Agent
# 4. Creates an Alias for invocation

set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

AGENT_DIR="$SCRIPT_DIR/../agent"

echo "=========================================="
echo "Bedrock Agent Creation"
echo "=========================================="
echo "Agent Name:  $AGENT_NAME"
echo "Region:      $AWS_REGION"
echo "Model:       Claude Sonnet 4"
echo ""

# Get role ARN
AGENT_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${AGENT_ROLE_NAME}"
LAMBDA_ARN="arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${LAMBDA_FUNCTION_NAME}"

# Read instructions
INSTRUCTIONS=$(cat "$AGENT_DIR/agent-instructions.txt")

# ==========================================
# Step 1: Create Agent
# ==========================================
echo "[1/4] Creating Bedrock Agent..."

# Check if agent already exists
EXISTING_AGENT=$(aws bedrock-agent list-agents --region "$AWS_REGION" \
    --query "agentSummaries[?agentName=='$AGENT_NAME'].agentId" --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_AGENT" ]; then
    echo "  Agent already exists: $EXISTING_AGENT"
    AGENT_ID="$EXISTING_AGENT"
else
    AGENT_RESPONSE=$(aws bedrock-agent create-agent \
        --agent-name "$AGENT_NAME" \
        --agent-resource-role-arn "$AGENT_ROLE_ARN" \
        --foundation-model "anthropic.claude-sonnet-4-20250514-v1:0" \
        --instruction "$INSTRUCTIONS" \
        --idle-session-ttl-in-seconds 600 \
        --description "Cost Explainer Agent POC - Answers questions about AWS spending" \
        --region "$AWS_REGION")

    AGENT_ID=$(echo "$AGENT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['agent']['agentId'])")
    echo "  Agent created: $AGENT_ID"
fi

# Wait for agent to be ready
echo "  Waiting for agent to be ready..."
sleep 5

echo ""

# ==========================================
# Step 2: Create Action Group
# ==========================================
echo "[2/4] Creating Action Group with Lambda binding..."

# Read OpenAPI schema
OPENAPI_SCHEMA=$(cat "$AGENT_DIR/openapi-schema.json")

# Check if action group exists
EXISTING_AG=$(aws bedrock-agent list-agent-action-groups \
    --agent-id "$AGENT_ID" \
    --agent-version "DRAFT" \
    --region "$AWS_REGION" \
    --query "actionGroupSummaries[?actionGroupName=='cost-explorer-actions'].actionGroupId" \
    --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_AG" ]; then
    echo "  Action group already exists: $EXISTING_AG"
else
    aws bedrock-agent create-agent-action-group \
        --agent-id "$AGENT_ID" \
        --agent-version "DRAFT" \
        --action-group-name "cost-explorer-actions" \
        --action-group-executor "lambda={lambdaArn=$LAMBDA_ARN}" \
        --api-schema "payload=$OPENAPI_SCHEMA" \
        --description "Actions for querying AWS cost data" \
        --region "$AWS_REGION"

    echo "  Action group created."
fi

echo ""

# ==========================================
# Step 3: Prepare Agent
# ==========================================
echo "[3/4] Preparing Agent..."

aws bedrock-agent prepare-agent \
    --agent-id "$AGENT_ID" \
    --region "$AWS_REGION"

echo "  Waiting for agent to be prepared..."
# Wait for preparation
for i in {1..30}; do
    STATUS=$(aws bedrock-agent get-agent \
        --agent-id "$AGENT_ID" \
        --region "$AWS_REGION" \
        --query 'agent.agentStatus' --output text)

    if [ "$STATUS" = "PREPARED" ]; then
        echo "  Agent prepared successfully."
        break
    elif [ "$STATUS" = "FAILED" ]; then
        echo "  ERROR: Agent preparation failed!"
        exit 1
    fi

    echo "  Status: $STATUS (waiting...)"
    sleep 5
done

echo ""

# ==========================================
# Step 4: Create Alias
# ==========================================
echo "[4/4] Creating Agent Alias..."

# Check if alias exists
EXISTING_ALIAS=$(aws bedrock-agent list-agent-aliases \
    --agent-id "$AGENT_ID" \
    --region "$AWS_REGION" \
    --query "agentAliasSummaries[?agentAliasName=='demo-alias'].agentAliasId" \
    --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_ALIAS" ]; then
    echo "  Alias already exists: $EXISTING_ALIAS"
    ALIAS_ID="$EXISTING_ALIAS"
else
    ALIAS_RESPONSE=$(aws bedrock-agent create-agent-alias \
        --agent-id "$AGENT_ID" \
        --agent-alias-name "demo-alias" \
        --description "Demo alias for testing" \
        --region "$AWS_REGION")

    ALIAS_ID=$(echo "$ALIAS_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['agentAlias']['agentAliasId'])")
    echo "  Alias created: $ALIAS_ID"
fi

# Wait for alias to be ready
echo "  Waiting for alias to be ready..."
sleep 10

echo ""

# ==========================================
# Summary
# ==========================================
echo "=========================================="
echo "Agent Creation Complete!"
echo "=========================================="
echo ""
echo "Agent ID:  $AGENT_ID"
echo "Alias ID:  $ALIAS_ID"
echo ""
echo "Save these for later use:"
echo "  export AGENT_ID=\"$AGENT_ID\""
echo "  export AGENT_ALIAS_ID=\"$ALIAS_ID\""
echo ""
echo "View in console:"
echo "  https://${AWS_REGION}.console.aws.amazon.com/bedrock/home?region=${AWS_REGION}#/agents/${AGENT_ID}"
echo ""
echo "Test the agent:"
echo "  aws bedrock-agent-runtime invoke-agent \\"
echo "    --agent-id \"$AGENT_ID\" \\"
echo "    --agent-alias-id \"$ALIAS_ID\" \\"
echo "    --session-id \"test-session\" \\"
echo "    --input-text \"What is my AWS spend this month?\" \\"
echo "    --region \"$AWS_REGION\""
echo ""
echo "Next: Run Ticket 8 to run the full test suite."
