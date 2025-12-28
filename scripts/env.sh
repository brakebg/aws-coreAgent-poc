#!/bin/bash
# Environment variables for Cost Explainer Agent POC
# Source this file before running other scripts:
#   source scripts/env.sh

# AWS Configuration
export AWS_REGION="eu-central-1"

# Dynamically fetch account ID from current AWS credentials
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "ERROR: Could not get AWS Account ID. Check your AWS credentials."
    return 1
fi

# IAM Role Names (prefix: demo-)
export LAMBDA_ROLE_NAME="demo-cost-explorer-tool-role"
export AGENT_ROLE_NAME="demo-cost-agent-role"

# Resource Names (prefix: demo-)
export LAMBDA_FUNCTION_NAME="demo-cost-explorer-tool"
export AGENT_NAME="demo-cost-explainer-agent"

# Anomaly Monitor - dynamically fetch the first available monitor
export ANOMALY_MONITOR_ARN=$(aws ce get-anomaly-monitors --query 'AnomalyMonitors[0].MonitorArn' --output text 2>/dev/null)
if [ "$ANOMALY_MONITOR_ARN" = "None" ] || [ -z "$ANOMALY_MONITOR_ARN" ]; then
    echo "WARNING: No anomaly monitor found. Run scripts/00-setup-anomaly-monitor.sh first."
    export ANOMALY_MONITOR_ARN=""
fi

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
echo "  Monitor:   ${ANOMALY_MONITOR_ARN:-'(not set)'}"
