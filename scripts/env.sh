#!/bin/bash
# Environment variables for Cost Explainer Agent POC
# Source this file before running other scripts:
#   source scripts/env.sh

# AWS Configuration
export AWS_REGION="eu-central-1"
export AWS_ACCOUNT_ID="058264262756"

# IAM Role Names (prefix: demo-)
export LAMBDA_ROLE_NAME="demo-cost-explorer-tool-role"
export AGENT_ROLE_NAME="demo-cost-agent-role"

# Resource Names (prefix: demo-)
export LAMBDA_FUNCTION_NAME="demo-cost-explorer-tool"
export AGENT_NAME="demo-cost-explainer-agent"

# Anomaly Monitor (existing in account)
export ANOMALY_MONITOR_ARN="arn:aws:ce::058264262756:anomalymonitor/4cd98946-59ec-4f8f-86da-b82980878068"

# Derived values (populated after resources are created)
export LAMBDA_ARN=""
export AGENT_ID=""
export AGENT_ALIAS_ID=""

# Verify
echo "Environment loaded:"
echo "  Region:    $AWS_REGION"
echo "  Account:   $AWS_ACCOUNT_ID"
echo "  Lambda:    $LAMBDA_FUNCTION_NAME"
echo "  Agent:     $AGENT_NAME"
