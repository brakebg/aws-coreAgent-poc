# Implementation Plan: Cost Explainer Agent POC

**Status:** Pending Approval
**PRD Version:** 1.1
**Owner:** Senior Engineering Manager
**Region:** eu-central-1 (Frankfurt)
**Approach:** Manual CLI Commands

---

## Overview

This plan implements a single-agent POC using AWS Bedrock AgentCore to answer natural language questions about AWS costs and detect anomalies.

---

## Infrastructure Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                     AWS ACCOUNT                                          │
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                              eu-central-1 (Frankfurt)                                │ │
│  │                                                                                      │ │
│  │    ┌──────────────┐                                                                  │ │
│  │    │    User      │                                                                  │ │
│  │    │  (CLI/SDK)   │                                                                  │ │
│  │    └──────┬───────┘                                                                  │ │
│  │           │                                                                          │ │
│  │           │ invoke-agent                                                             │ │
│  │           ▼                                                                          │ │
│  │    ┌─────────────────────────────────────────────────────────────────┐               │ │
│  │    │                    AMAZON BEDROCK                                │               │ │
│  │    │  ┌───────────────────────────────────────────────────────────┐  │               │ │
│  │    │  │                  AgentCore Runtime                         │  │               │ │
│  │    │  │  ┌─────────────────────────────────────────────────────┐  │  │               │ │
│  │    │  │  │           cost-explainer-agent                       │  │  │               │ │
│  │    │  │  │           Alias: "live"                              │  │  │               │ │
│  │    │  │  │                                                      │  │  │               │ │
│  │    │  │  │  ┌────────────────────────────────────────────────┐ │  │  │               │ │
│  │    │  │  │  │         Claude Sonnet 4 (Foundation Model)     │ │  │  │               │ │
│  │    │  │  │  │                                                 │ │  │  │               │ │
│  │    │  │  │  │  • Interprets user questions                   │ │  │  │               │ │
│  │    │  │  │  │  • Decides which tools to call                 │ │  │  │               │ │
│  │    │  │  │  │  • Reasons over results                        │ │  │  │               │ │
│  │    │  │  │  │  • Generates natural language response         │ │  │  │               │ │
│  │    │  │  │  └────────────────────────────────────────────────┘ │  │  │               │ │
│  │    │  │  │                         │                           │  │  │               │ │
│  │    │  │  │  ┌──────────────────────┴────────────────────────┐  │  │  │               │ │
│  │    │  │  │  │           Action Group                         │  │  │  │               │ │
│  │    │  │  │  │        "cost-explorer-actions"                 │  │  │  │               │ │
│  │    │  │  │  │                                                │  │  │  │               │ │
│  │    │  │  │  │   OpenAPI Schema defines:                      │  │  │  │               │ │
│  │    │  │  │  │   • /get_cost_and_usage                        │  │  │  │               │ │
│  │    │  │  │  │   • /get_cost_forecast                         │  │  │  │               │ │
│  │    │  │  │  │   • /get_anomalies                             │  │  │  │               │ │
│  │    │  │  │  └────────────────────┬───────────────────────────┘  │  │  │               │ │
│  │    │  │  └───────────────────────┼──────────────────────────────┘  │  │               │ │
│  │    │  └──────────────────────────┼─────────────────────────────────┘  │               │ │
│  │    └─────────────────────────────┼────────────────────────────────────┘               │ │
│  │                                  │                                                    │ │
│  │                                  │ lambda:InvokeFunction                              │ │
│  │                                  ▼                                                    │ │
│  │    ┌─────────────────────────────────────────────────────────────────┐               │ │
│  │    │                      AWS LAMBDA                                  │               │ │
│  │    │  ┌───────────────────────────────────────────────────────────┐  │               │ │
│  │    │  │              cost-explorer-tool                            │  │               │ │
│  │    │  │              Runtime: Python 3.11                          │  │               │ │
│  │    │  │              Memory: 256 MB | Timeout: 30s                 │  │               │ │
│  │    │  │                                                            │  │               │ │
│  │    │  │  lambda_function.py                                        │  │               │ │
│  │    │  │  ├── get_cost_and_usage()                                  │  │               │ │
│  │    │  │  ├── get_cost_forecast()                                   │  │               │ │
│  │    │  │  └── get_anomalies()                                       │  │               │ │
│  │    │  └───────────────────────────────────────────────────────────┘  │               │ │
│  │    └─────────────────────────────┬───────────────────────────────────┘               │ │
│  │                                  │                                                    │ │
│  └──────────────────────────────────┼────────────────────────────────────────────────────┘ │
│                                     │                                                      │
│                                     │ ce:GetCostAndUsage                                   │
│                                     │ ce:GetCostForecast                                   │
│                                     │ ce:GetAnomalies                                      │
│                                     ▼                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                              us-east-1 (Global Services)                             │  │
│  │                                                                                      │  │
│  │   ┌────────────────────────────────────────────────────────────────────────────┐    │  │
│  │   │                        AWS COST EXPLORER API                                │    │  │
│  │   │                                                                             │    │  │
│  │   │   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐    │    │  │
│  │   │   │ GetCostAndUsage │  │ GetCostForecast │  │ Anomaly Detection       │    │    │  │
│  │   │   │                 │  │                 │  │                         │    │    │  │
│  │   │   │ • By SERVICE    │  │ • 30-day ahead  │  │ ┌─────────────────────┐ │    │    │  │
│  │   │   │ • By REGION     │  │ • Confidence    │  │ │ AllServicesMonitor  │ │    │    │  │
│  │   │   │ • By INSTANCE   │  │   intervals     │  │ │ (DIMENSIONAL)       │ │    │    │  │
│  │   │   │ • DAILY/MONTHLY │  │                 │  │ │                     │ │    │    │  │
│  │   │   └─────────────────┘  └─────────────────┘  │ │ ML-based detection  │ │    │    │  │
│  │   │                                             │ │ Root cause analysis │ │    │    │  │
│  │   │                                             │ └─────────────────────┘ │    │    │  │
│  │   │                                             └─────────────────────────┘    │    │  │
│  │   └────────────────────────────────────────────────────────────────────────────┘    │  │
│  │                                                                                      │  │
│  └──────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                            │
└────────────────────────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                   IAM ROLES & POLICIES                                   │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌────────────────────────────────────┐    ┌────────────────────────────────────────┐   │
│  │      cost-agent-role               │    │      cost-explorer-tool-role           │   │
│  │      (Bedrock Agent)               │    │      (Lambda Execution)                │   │
│  │                                    │    │                                        │   │
│  │  Trust: bedrock.amazonaws.com      │    │  Trust: lambda.amazonaws.com           │   │
│  │                                    │    │                                        │   │
│  │  Permissions:                      │    │  Permissions:                          │   │
│  │  • bedrock:InvokeModel            │    │  • ce:GetCostAndUsage                  │   │
│  │  • bedrock:InvokeModelWith...     │    │  • ce:GetCostForecast                  │   │
│  │  • lambda:InvokeFunction          │    │  • ce:GetAnomalies                     │   │
│  │    (cost-explorer-tool only)      │    │  • ce:GetAnomalyMonitors               │   │
│  │                                    │    │  • logs:CreateLogGroup                 │   │
│  │                                    │    │  • logs:CreateLogStream                │   │
│  │                                    │    │  • logs:PutLogEvents                   │   │
│  └────────────────────────────────────┘    └────────────────────────────────────────┘   │
│                                                                                          │
│  Lambda Resource Policy:                                                                 │
│  └── AllowBedrockInvoke: bedrock.amazonaws.com can invoke cost-explorer-tool            │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                   OBSERVABILITY                                          │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐    │
│  │                           AMAZON CLOUDWATCH                                      │    │
│  │                                                                                  │    │
│  │   Log Groups:                          Metrics:                                  │    │
│  │   ┌────────────────────────────┐      ┌────────────────────────────────────┐    │    │
│  │   │ /aws/lambda/               │      │ AWS/Lambda                          │    │    │
│  │   │   cost-explorer-tool       │      │ • Invocations                       │    │    │
│  │   │                            │      │ • Duration                          │    │    │
│  │   │ • Function logs            │      │ • Errors                            │    │    │
│  │   │ • API call details         │      │ • Throttles                         │    │    │
│  │   │ • Error traces             │      └────────────────────────────────────┘    │    │
│  │   └────────────────────────────┘                                                │    │
│  │                                        Dashboard:                                │    │
│  │   Agent Traces (Bedrock Console):      ┌────────────────────────────────────┐    │    │
│  │   ┌────────────────────────────┐      │ CostExplainerAgent                  │    │    │
│  │   │ • Reasoning steps          │      │ • Lambda Invocations                │    │    │
│  │   │ • Tool selections          │      │ • Lambda Duration                   │    │    │
│  │   │ • Tool call parameters     │      │ • Lambda Errors                     │    │    │
│  │   │ • Response generation      │      └────────────────────────────────────┘    │    │
│  │   └────────────────────────────┘                                                │    │
│  │                                                                                  │    │
│  └─────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                   DATA FLOW                                              │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  1. USER INVOCATION                                                                      │
│     User ──► bedrock-agent-runtime:invoke-agent ──► AgentCore                           │
│                                                                                          │
│  2. AGENT REASONING                                                                      │
│     AgentCore ──► Claude Sonnet 4 ──► "I need to call get_cost_and_usage"               │
│                                                                                          │
│  3. TOOL EXECUTION                                                                       │
│     AgentCore ──► Lambda (cost-explorer-tool) ──► Cost Explorer API                     │
│                                                                                          │
│  4. RESPONSE SYNTHESIS                                                                   │
│     Cost Explorer ──► Lambda ──► AgentCore ──► Claude Sonnet 4 ──► Natural Language     │
│                                                                                          │
│  5. STREAMING RESPONSE                                                                   │
│     AgentCore ──► User (streaming chunks)                                               │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites Checklist

Before starting implementation:

| Item | Check | Verification Command |
|------|-------|---------------------|
| AWS Account with admin access | ☐ | `aws sts get-caller-identity` |
| AWS CLI v2 configured for eu-central-1 | ☐ | `aws configure get region` |
| Python 3.11+ installed | ☐ | `python3 --version` |
| Cost Explorer enabled | ☐ | `aws ce get-cost-and-usage --time-period Start=2025-12-01,End=2025-12-02 --granularity DAILY --metrics UnblendedCost` |
| Bedrock model access (Claude) | ☐ | Check Bedrock console → Model access |
| Anomaly monitor created | ☐ | See Phase 0 below |
| Billing alert at $25 | ☐ | Set in AWS Budgets |

---

## Project Structure

```
poc-coreAgent-costanomaly/
├── PRD.md                      # Product requirements (done)
├── IMPLEMENTATION_PLAN.md      # This file
├── LEARNINGS.md                # Document findings as you go
│
├── infrastructure/
│   └── iam-policies/
│       ├── lambda-trust-policy.json
│       ├── lambda-permissions-policy.json
│       ├── agent-trust-policy.json
│       └── agent-permissions-policy.json
│
├── lambda/
│   └── cost-explorer-tool/
│       ├── lambda_function.py  # Lambda handler
│       └── deploy.zip          # Deployment package
│
├── agent/
│   ├── agent-instructions.txt  # System prompt
│   └── openapi-schema.json     # Tool schema
│
├── scripts/
│   ├── 00-setup-anomaly-monitor.sh  # Phase 0: Anomaly monitor
│   ├── 01-setup-iam.sh              # Phase 1: IAM setup
│   ├── 02-deploy-lambda.sh          # Phase 2: Lambda deployment
│   ├── 03-create-agent.sh           # Phase 3: Agent creation
│   ├── 04-test-agent.py             # Phase 4: Test script
│   └── 99-cleanup.sh                # Teardown
│
└── tests/
    └── test-queries.md         # Test cases + results
```

---

## Phase 0: Create Anomaly Monitor (One-time Setup)

**Goal:** Enable AWS Cost Anomaly Detection for the account

> **Note:** AWS needs ~10 days to train the ML model after creating a monitor. For the POC, the API will work immediately but may return "0 anomalies" until the model trains. This is expected behavior.

### Step 0.1: Check for Existing Monitors

```bash
# Check if any monitors already exist
aws ce get-anomaly-monitors \
  --query 'AnomalyMonitors[*].[MonitorName,MonitorType,MonitorArn]' \
  --output table

# If this returns results, skip to Phase 1
# If empty, continue with Step 0.2
```

### Step 0.2: Create Anomaly Monitor

```bash
# Create a monitor that watches all AWS services
# Note: Cost Explorer API always uses us-east-1 regardless of resource location

aws ce create-anomaly-monitor \
  --anomaly-monitor '{
    "MonitorName": "AllServicesMonitor",
    "MonitorType": "DIMENSIONAL",
    "MonitorDimension": "SERVICE"
  }'

# Expected output:
# {
#   "MonitorArn": "arn:aws:ce::123456789012:anomalymonitor/abc123..."
# }
```

### Step 0.3: (Optional) Create Alert Subscription

```bash
# Get the monitor ARN from previous step
MONITOR_ARN=$(aws ce get-anomaly-monitors --query 'AnomalyMonitors[0].MonitorArn' --output text)

# Create email subscription for alerts (optional but useful)
aws ce create-anomaly-subscription \
  --anomaly-subscription "{
    \"SubscriptionName\": \"CostAnomalyAlerts\",
    \"MonitorArnList\": [\"$MONITOR_ARN\"],
    \"Subscribers\": [{
      \"Type\": \"EMAIL\",
      \"Address\": \"your-email@example.com\"
    }],
    \"Frequency\": \"DAILY\",
    \"ThresholdExpression\": {
      \"Dimensions\": {
        \"Key\": \"ANOMALY_TOTAL_IMPACT_ABSOLUTE\",
        \"Values\": [\"10\"],
        \"MatchOptions\": [\"GREATER_THAN_OR_EQUAL\"]
      }
    }
  }"

# This sends email alerts for anomalies with impact >= $10
```

### Step 0.4: Verify Monitor Created

```bash
# Verify monitor exists
aws ce get-anomaly-monitors \
  --query 'AnomalyMonitors[*].[MonitorName,MonitorType,CreationDate]' \
  --output table

# Expected output:
# ---------------------------------------------------------
# |               GetAnomalyMonitors                       |
# +---------------------+-------------+--------------------+
# |  AllServicesMonitor |  DIMENSIONAL|  2025-12-27T...   |
# +---------------------+-------------+--------------------+

echo "=== Phase 0 Complete ==="
echo "Anomaly monitor created. ML model will train over ~10 days."
echo "API calls will work immediately but may return 0 anomalies initially."
```

---

## Phase 1: Foundation Setup

**Goal:** IAM roles and permissions ready

### Step 1.1: Set Environment Variables

```bash
# scripts/env.sh - Source this first
export AWS_REGION="eu-central-1"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export LAMBDA_ROLE_NAME="cost-explorer-tool-role"
export AGENT_ROLE_NAME="cost-agent-role"
export LAMBDA_FUNCTION_NAME="cost-explorer-tool"
export AGENT_NAME="cost-explainer-agent"

echo "AWS Account: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
```

### Step 1.2: Create Lambda Trust Policy

```bash
# Create file: infrastructure/iam-policies/lambda-trust-policy.json
cat > infrastructure/iam-policies/lambda-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

### Step 1.3: Create Lambda Permissions Policy

```bash
# Create file: infrastructure/iam-policies/lambda-permissions-policy.json
cat > infrastructure/iam-policies/lambda-permissions-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CostExplorerReadAccess",
      "Effect": "Allow",
      "Action": [
        "ce:GetCostAndUsage",
        "ce:GetCostForecast",
        "ce:GetAnomalies",
        "ce:GetAnomalyMonitors"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:eu-central-1:*:*"
    }
  ]
}
EOF
```

### Step 1.4: Create Lambda IAM Role

```bash
# scripts/01-setup-iam.sh

#!/bin/bash
set -e
source scripts/env.sh

echo "Creating Lambda execution role..."

# Create the role
aws iam create-role \
  --role-name $LAMBDA_ROLE_NAME \
  --assume-role-policy-document file://infrastructure/iam-policies/lambda-trust-policy.json \
  --description "Role for Cost Explorer Tool Lambda"

# Attach the permissions policy
aws iam put-role-policy \
  --role-name $LAMBDA_ROLE_NAME \
  --policy-name CostExplorerToolPolicy \
  --policy-document file://infrastructure/iam-policies/lambda-permissions-policy.json

echo "Lambda role created: $LAMBDA_ROLE_NAME"
echo "Waiting 10 seconds for IAM propagation..."
sleep 10
```

### Step 1.5: Create Agent Trust Policy

```bash
# Create file: infrastructure/iam-policies/agent-trust-policy.json
cat > infrastructure/iam-policies/agent-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "bedrock.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "${AWS_ACCOUNT_ID}"
        },
        "ArnLike": {
          "aws:SourceArn": "arn:aws:bedrock:eu-central-1:${AWS_ACCOUNT_ID}:agent/*"
        }
      }
    }
  ]
}
EOF

# Replace placeholder with actual account ID
envsubst < infrastructure/iam-policies/agent-trust-policy.json > infrastructure/iam-policies/agent-trust-policy-resolved.json
```

### Step 1.6: Create Agent Permissions Policy

```bash
# Create file: infrastructure/iam-policies/agent-permissions-policy.json
cat > infrastructure/iam-policies/agent-permissions-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BedrockModelAccess",
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "arn:aws:bedrock:eu-central-1::foundation-model/anthropic.claude-sonnet-4*"
    },
    {
      "Sid": "LambdaInvoke",
      "Effect": "Allow",
      "Action": "lambda:InvokeFunction",
      "Resource": "arn:aws:lambda:eu-central-1:${AWS_ACCOUNT_ID}:function:cost-explorer-tool"
    }
  ]
}
EOF
```

### Step 1.7: Create Agent IAM Role

```bash
# Add to scripts/01-setup-iam.sh

echo "Creating Agent execution role..."

# Create the role
aws iam create-role \
  --role-name $AGENT_ROLE_NAME \
  --assume-role-policy-document file://infrastructure/iam-policies/agent-trust-policy-resolved.json \
  --description "Role for Cost Explainer Bedrock Agent"

# Attach the permissions policy (resolve account ID first)
envsubst < infrastructure/iam-policies/agent-permissions-policy.json > infrastructure/iam-policies/agent-permissions-policy-resolved.json

aws iam put-role-policy \
  --role-name $AGENT_ROLE_NAME \
  --policy-name CostAgentPolicy \
  --policy-document file://infrastructure/iam-policies/agent-permissions-policy-resolved.json

echo "Agent role created: $AGENT_ROLE_NAME"
```

### Step 1.8: Verify Setup

```bash
# Verification commands
echo "=== Verifying IAM Setup ==="

# Check roles exist
aws iam get-role --role-name $LAMBDA_ROLE_NAME --query 'Role.Arn' --output text
aws iam get-role --role-name $AGENT_ROLE_NAME --query 'Role.Arn' --output text

# Test Cost Explorer access (with your credentials)
aws ce get-cost-and-usage \
  --time-period Start=2025-12-01,End=2025-12-27 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[0].Groups[0:3]'

# Check anomaly monitors
aws ce get-anomaly-monitors --query 'AnomalyMonitors[*].MonitorName'

echo "=== Phase 1 Complete ==="
```

---

## Phase 2: Lambda Tool Implementation

**Goal:** Working Lambda that queries Cost Explorer

### Step 2.1: Create Lambda Function Code

```bash
# Create file: lambda/cost-explorer-tool/lambda_function.py
cat > lambda/cost-explorer-tool/lambda_function.py << 'PYTHON'
"""
Cost Explorer Tool for Bedrock Agent
Provides cost data, forecasts, and anomaly detection.
"""

import boto3
import json
from datetime import datetime, timedelta
from typing import Any

ce_client = boto3.client('ce', region_name='us-east-1')  # Cost Explorer is global, use us-east-1


def lambda_handler(event: dict, context: Any) -> dict:
    """
    Main handler for Bedrock Agent tool invocations.

    Event structure from Bedrock Agent:
    {
        "actionGroup": "cost-explorer",
        "apiPath": "/get_cost_and_usage",
        "httpMethod": "POST",
        "parameters": [...],
        "requestBody": {
            "content": {
                "application/json": {
                    "properties": [...]
                }
            }
        }
    }
    """
    print(f"Received event: {json.dumps(event)}")

    try:
        # Extract action from apiPath
        api_path = event.get('apiPath', '')
        action = api_path.strip('/').replace('/', '_')

        # Extract parameters from requestBody
        params = {}
        request_body = event.get('requestBody', {})
        if request_body:
            content = request_body.get('content', {})
            json_content = content.get('application/json', {})
            properties = json_content.get('properties', [])
            for prop in properties:
                params[prop.get('name')] = prop.get('value')

        print(f"Action: {action}, Params: {params}")

        # Route to appropriate handler
        if action == 'get_cost_and_usage':
            result = get_cost_and_usage(params)
        elif action == 'get_cost_forecast':
            result = get_cost_forecast(params)
        elif action == 'get_anomalies':
            result = get_anomalies(params)
        else:
            result = {'error': f'Unknown action: {action}'}

        # Format response for Bedrock Agent
        return {
            'messageVersion': '1.0',
            'response': {
                'actionGroup': event.get('actionGroup', 'cost-explorer'),
                'apiPath': api_path,
                'httpMethod': event.get('httpMethod', 'POST'),
                'httpStatusCode': 200,
                'responseBody': {
                    'application/json': {
                        'body': json.dumps(result)
                    }
                }
            }
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'messageVersion': '1.0',
            'response': {
                'actionGroup': event.get('actionGroup', 'cost-explorer'),
                'apiPath': event.get('apiPath', ''),
                'httpMethod': event.get('httpMethod', 'POST'),
                'httpStatusCode': 500,
                'responseBody': {
                    'application/json': {
                        'body': json.dumps({'error': str(e)})
                    }
                }
            }
        }


def get_cost_and_usage(params: dict) -> dict:
    """Get cost breakdown by service/region for a time period."""

    days_back = int(params.get('days_back', 30))
    granularity = params.get('granularity', 'MONTHLY').upper()
    group_by = params.get('group_by', 'SERVICE').upper()

    end_date = datetime.now().strftime('%Y-%m-%d')
    start_date = (datetime.now() - timedelta(days=days_back)).strftime('%Y-%m-%d')

    response = ce_client.get_cost_and_usage(
        TimePeriod={'Start': start_date, 'End': end_date},
        Granularity=granularity,
        Metrics=['UnblendedCost', 'UsageQuantity'],
        GroupBy=[{'Type': 'DIMENSION', 'Key': group_by}]
    )

    # Simplify response for agent consumption
    results = []
    for period in response.get('ResultsByTime', []):
        period_data = {
            'start': period['TimePeriod']['Start'],
            'end': period['TimePeriod']['End'],
            'groups': []
        }
        for group in period.get('Groups', []):
            period_data['groups'].append({
                'name': group['Keys'][0],
                'cost': float(group['Metrics']['UnblendedCost']['Amount']),
                'unit': group['Metrics']['UnblendedCost']['Unit']
            })
        # Sort by cost descending
        period_data['groups'].sort(key=lambda x: x['cost'], reverse=True)
        results.append(period_data)

    # Calculate total
    total_cost = sum(
        g['cost']
        for r in results
        for g in r['groups']
    )

    return {
        'time_period': {'start': start_date, 'end': end_date},
        'granularity': granularity,
        'grouped_by': group_by,
        'total_cost': round(total_cost, 2),
        'currency': 'USD',
        'results': results
    }


def get_cost_forecast(params: dict) -> dict:
    """Get cost forecast for upcoming period."""

    days_ahead = int(params.get('days_ahead', 30))

    # Forecast must start from tomorrow or later
    start_date = (datetime.now() + timedelta(days=1)).strftime('%Y-%m-%d')
    end_date = (datetime.now() + timedelta(days=days_ahead)).strftime('%Y-%m-%d')

    try:
        response = ce_client.get_cost_forecast(
            TimePeriod={'Start': start_date, 'End': end_date},
            Metric='UNBLENDED_COST',
            Granularity='MONTHLY',
            PredictionIntervalLevel=80
        )

        return {
            'forecast_period': {'start': start_date, 'end': end_date},
            'predicted_total': float(response['Total']['Amount']),
            'currency': response['Total']['Unit'],
            'confidence_level': '80%',
            'lower_bound': float(response.get('ForecastResultsByTime', [{}])[0].get('PredictionIntervalLowerBound', 0)),
            'upper_bound': float(response.get('ForecastResultsByTime', [{}])[0].get('PredictionIntervalUpperBound', 0))
        }

    except ce_client.exceptions.DataUnavailableException:
        return {
            'error': 'Insufficient data for forecast. Need at least 10 days of cost history.',
            'forecast_period': {'start': start_date, 'end': end_date}
        }


def get_anomalies(params: dict) -> dict:
    """Get detected cost anomalies."""

    days_back = int(params.get('days_back', 30))

    start_date = (datetime.now() - timedelta(days=days_back)).strftime('%Y-%m-%d')
    end_date = datetime.now().strftime('%Y-%m-%d')

    # First check if monitors exist
    monitors_response = ce_client.get_anomaly_monitors(MaxResults=10)
    monitors = monitors_response.get('AnomalyMonitors', [])

    if not monitors:
        return {
            'anomalies': [],
            'count': 0,
            'message': 'No anomaly monitors configured. You have existing monitors - check AWS Cost Explorer console.',
            'lookback_days': days_back
        }

    # Get anomalies
    response = ce_client.get_anomalies(
        DateInterval={
            'StartDate': start_date,
            'EndDate': end_date
        },
        MaxResults=20
    )

    anomalies = []
    for anomaly in response.get('Anomalies', []):
        impact = anomaly.get('Impact', {})
        root_causes = anomaly.get('RootCauses', [])

        anomaly_data = {
            'id': anomaly.get('AnomalyId'),
            'start_date': anomaly.get('AnomalyStartDate'),
            'end_date': anomaly.get('AnomalyEndDate'),
            'expected_spend': float(impact.get('TotalExpectedSpend', 0)),
            'actual_spend': float(impact.get('TotalActualSpend', 0)),
            'impact_amount': float(impact.get('TotalImpact', 0)),
            'impact_percentage': float(impact.get('TotalImpactPercentage', 0)),
            'root_causes': []
        }

        for cause in root_causes[:3]:  # Top 3 root causes
            anomaly_data['root_causes'].append({
                'service': cause.get('Service', 'Unknown'),
                'region': cause.get('Region', 'Unknown'),
                'usage_type': cause.get('UsageType', 'Unknown'),
                'linked_account': cause.get('LinkedAccount', 'N/A')
            })

        anomalies.append(anomaly_data)

    # Sort by impact amount descending
    anomalies.sort(key=lambda x: x['impact_amount'], reverse=True)

    return {
        'anomalies': anomalies,
        'count': len(anomalies),
        'lookback_days': days_back,
        'monitors_active': len(monitors)
    }
PYTHON
```

### Step 2.2: Package and Deploy Lambda

```bash
# scripts/02-deploy-lambda.sh

#!/bin/bash
set -e
source scripts/env.sh

echo "Packaging Lambda function..."

cd lambda/cost-explorer-tool
zip -r deploy.zip lambda_function.py
cd ../..

echo "Creating Lambda function..."

LAMBDA_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${LAMBDA_ROLE_NAME}"

aws lambda create-function \
  --function-name $LAMBDA_FUNCTION_NAME \
  --runtime python3.11 \
  --role $LAMBDA_ROLE_ARN \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://lambda/cost-explorer-tool/deploy.zip \
  --timeout 30 \
  --memory-size 256 \
  --region $AWS_REGION \
  --description "Cost Explorer tool for Bedrock Agent"

echo "Lambda function created: $LAMBDA_FUNCTION_NAME"

# Add resource-based policy for Bedrock Agent to invoke
echo "Adding Bedrock invoke permission..."

aws lambda add-permission \
  --function-name $LAMBDA_FUNCTION_NAME \
  --statement-id AllowBedrockInvoke \
  --action lambda:InvokeFunction \
  --principal bedrock.amazonaws.com \
  --source-arn "arn:aws:bedrock:${AWS_REGION}:${AWS_ACCOUNT_ID}:agent/*" \
  --region $AWS_REGION

echo "=== Phase 2 Complete ==="
```

### Step 2.3: Test Lambda Directly

```bash
# Test get_cost_and_usage
aws lambda invoke \
  --function-name cost-explorer-tool \
  --payload '{"apiPath": "/get_cost_and_usage", "requestBody": {"content": {"application/json": {"properties": [{"name": "days_back", "value": "30"}, {"name": "group_by", "value": "SERVICE"}]}}}}' \
  --region eu-central-1 \
  /tmp/lambda-response.json

cat /tmp/lambda-response.json | jq .

# Test get_anomalies
aws lambda invoke \
  --function-name cost-explorer-tool \
  --payload '{"apiPath": "/get_anomalies", "requestBody": {"content": {"application/json": {"properties": [{"name": "days_back", "value": "30"}]}}}}' \
  --region eu-central-1 \
  /tmp/lambda-anomalies.json

cat /tmp/lambda-anomalies.json | jq .
```

---

## Phase 3: Agent Creation

**Goal:** AgentCore agent configured and working

### Step 3.1: Create Agent Instructions

```bash
# Create file: agent/agent-instructions.txt
cat > agent/agent-instructions.txt << 'EOF'
You are a Cost Explainer Agent that helps users understand their AWS spending.

## Your Capabilities
- Query AWS Cost Explorer for spending data by service, region, or instance type
- Compare costs across different time periods
- Retrieve cost forecasts for budget planning
- Detect and explain cost anomalies with root cause analysis

## How to Respond
1. First understand what the user wants to know about their costs
2. Use the appropriate tool to get real data:
   - get_cost_and_usage: For current and historical spend breakdown
   - get_cost_forecast: For predicted future spend
   - get_anomalies: For ML-detected unusual spending patterns
3. Present findings in plain English with specific dollar amounts
4. Calculate percentages and comparisons when relevant
5. Highlight unusual patterns or significant changes
6. Provide actionable observations when possible

## Response Format
- Use bullet points for clarity
- Always include actual dollar amounts (e.g., $142.30, not "around $140")
- Show percentage changes when comparing periods (e.g., "+15%")
- Keep responses concise but complete
- For anomalies, always explain the root cause (service, region, usage type)

## Important Constraints
- You only have READ access to cost data - you cannot modify anything
- Cost data is 24 hours behind real-time
- Forecasts require at least 10 days of historical data
- Anomaly detection uses AWS's ML models trained on account history
EOF
```

### Step 3.2: Create OpenAPI Schema

```bash
# Create file: agent/openapi-schema.json
cat > agent/openapi-schema.json << 'EOF'
{
  "openapi": "3.0.0",
  "info": {
    "title": "Cost Explorer Tool",
    "version": "1.0.0",
    "description": "Tool for querying AWS Cost Explorer data"
  },
  "paths": {
    "/get_cost_and_usage": {
      "post": {
        "operationId": "get_cost_and_usage",
        "summary": "Get AWS cost and usage data",
        "description": "Retrieves cost breakdown by service, region, or instance type for a specified time period. Use this for questions about spending, bills, and cost breakdowns.",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "days_back": {
                    "type": "integer",
                    "default": 30,
                    "description": "Number of days of history to retrieve (1-90)"
                  },
                  "granularity": {
                    "type": "string",
                    "enum": ["DAILY", "MONTHLY"],
                    "default": "MONTHLY",
                    "description": "Time granularity - DAILY for day-by-day, MONTHLY for monthly totals"
                  },
                  "group_by": {
                    "type": "string",
                    "enum": ["SERVICE", "REGION", "INSTANCE_TYPE"],
                    "default": "SERVICE",
                    "description": "Dimension to group costs by"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Cost data retrieved successfully",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "total_cost": {"type": "number"},
                    "currency": {"type": "string"},
                    "results": {"type": "array"}
                  }
                }
              }
            }
          }
        }
      }
    },
    "/get_cost_forecast": {
      "post": {
        "operationId": "get_cost_forecast",
        "summary": "Get AWS cost forecast",
        "description": "Retrieves predicted AWS spending for the upcoming period. Use this when users ask about future costs or budget planning.",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "days_ahead": {
                    "type": "integer",
                    "default": 30,
                    "description": "Number of days to forecast (1-90)"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Forecast retrieved successfully",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "predicted_total": {"type": "number"},
                    "currency": {"type": "string"},
                    "confidence_level": {"type": "string"}
                  }
                }
              }
            }
          }
        }
      }
    },
    "/get_anomalies": {
      "post": {
        "operationId": "get_anomalies",
        "summary": "Get detected cost anomalies",
        "description": "Retrieves ML-detected unusual spending patterns with root causes. Use this when users ask about spikes, unusual costs, or anomalies.",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "days_back": {
                    "type": "integer",
                    "default": 30,
                    "description": "Number of days to look back for anomalies (1-90)"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Anomalies retrieved successfully",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "count": {"type": "integer"},
                    "anomalies": {"type": "array"}
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
EOF
```

### Step 3.3: Create Agent via CLI

```bash
# scripts/03-create-agent.sh

#!/bin/bash
set -e
source scripts/env.sh

echo "Creating Bedrock Agent..."

AGENT_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${AGENT_ROLE_NAME}"
LAMBDA_ARN="arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${LAMBDA_FUNCTION_NAME}"

# Read instructions
INSTRUCTIONS=$(cat agent/agent-instructions.txt)

# Create agent
AGENT_RESPONSE=$(aws bedrock-agent create-agent \
  --agent-name "$AGENT_NAME" \
  --agent-resource-role-arn "$AGENT_ROLE_ARN" \
  --foundation-model "anthropic.claude-sonnet-4-20250514-v1:0" \
  --instruction "$INSTRUCTIONS" \
  --idle-session-ttl-in-seconds 600 \
  --description "POC agent for explaining AWS costs and detecting anomalies" \
  --region $AWS_REGION)

AGENT_ID=$(echo $AGENT_RESPONSE | jq -r '.agent.agentId')
echo "Agent created with ID: $AGENT_ID"

# Save agent ID for later use
echo "export AGENT_ID=$AGENT_ID" >> scripts/env.sh

# Wait for agent to be ready
echo "Waiting for agent to be ready..."
aws bedrock-agent get-agent --agent-id $AGENT_ID --region $AWS_REGION \
  --query 'agent.agentStatus' --output text

sleep 5

# Create action group with Lambda tool
echo "Creating action group..."

aws bedrock-agent create-agent-action-group \
  --agent-id $AGENT_ID \
  --agent-version "DRAFT" \
  --action-group-name "cost-explorer-actions" \
  --action-group-executor "lambda={lambdaArn=$LAMBDA_ARN}" \
  --api-schema "payload=$(cat agent/openapi-schema.json | base64)" \
  --description "Actions for querying AWS Cost Explorer" \
  --region $AWS_REGION

echo "Action group created."

# Prepare agent
echo "Preparing agent..."
aws bedrock-agent prepare-agent \
  --agent-id $AGENT_ID \
  --region $AWS_REGION

echo "Waiting for agent preparation..."
sleep 30

# Create alias for invocation
echo "Creating agent alias..."
ALIAS_RESPONSE=$(aws bedrock-agent create-agent-alias \
  --agent-id $AGENT_ID \
  --agent-alias-name "live" \
  --description "Live alias for testing" \
  --region $AWS_REGION)

ALIAS_ID=$(echo $ALIAS_RESPONSE | jq -r '.agentAlias.agentAliasId')
echo "export ALIAS_ID=$ALIAS_ID" >> scripts/env.sh

echo "=== Phase 3 Complete ==="
echo "Agent ID: $AGENT_ID"
echo "Alias ID: $ALIAS_ID"
```

---

## Phase 4: Testing & Validation

### Step 4.1: Test Script

```python
# scripts/04-test-agent.py

#!/usr/bin/env python3
"""
Test script for Cost Explainer Agent.
Invokes the agent with test queries and displays results.
"""

import boto3
import json
import os
import sys
from datetime import datetime

# Configuration
REGION = os.environ.get('AWS_REGION', 'eu-central-1')
AGENT_ID = os.environ.get('AGENT_ID')
ALIAS_ID = os.environ.get('ALIAS_ID')

if not AGENT_ID or not ALIAS_ID:
    print("Error: Set AGENT_ID and ALIAS_ID environment variables")
    print("Run: source scripts/env.sh")
    sys.exit(1)

client = boto3.client('bedrock-agent-runtime', region_name=REGION)


def invoke_agent(query: str, session_id: str = None) -> str:
    """Invoke the agent with a query and return the response."""

    if not session_id:
        session_id = f"test-{datetime.now().strftime('%Y%m%d-%H%M%S')}"

    print(f"\n{'='*60}")
    print(f"Query: {query}")
    print(f"{'='*60}")

    response = client.invoke_agent(
        agentId=AGENT_ID,
        agentAliasId=ALIAS_ID,
        sessionId=session_id,
        inputText=query,
        enableTrace=True
    )

    # Process streaming response
    full_response = ""
    traces = []

    for event in response['completion']:
        if 'chunk' in event:
            chunk = event['chunk']
            if 'bytes' in chunk:
                text = chunk['bytes'].decode('utf-8')
                full_response += text
                print(text, end='', flush=True)

        if 'trace' in event:
            traces.append(event['trace'])

    print(f"\n{'='*60}")

    # Show trace summary
    if traces:
        print("\nTrace Summary:")
        for trace in traces:
            trace_data = trace.get('trace', {})
            if 'orchestrationTrace' in trace_data:
                orch = trace_data['orchestrationTrace']
                if 'invocationInput' in orch:
                    print(f"  → Tool call: {orch['invocationInput'].get('actionGroupInvocationInput', {}).get('apiPath', 'unknown')}")
                if 'observation' in orch:
                    print(f"  ← Response received")

    return full_response


def run_test_suite():
    """Run all test queries."""

    test_queries = [
        # Basic queries
        ("Basic Spend", "What's my AWS spend this month?"),
        ("Comparison", "How does this month compare to last month?"),
        ("Top Service", "What's my most expensive service?"),

        # Anomaly detection
        ("Anomalies", "Are there any cost anomalies?"),
        ("Weekly Check", "Any unusual spending this week?"),

        # Forecast
        ("Forecast", "What will I spend next month?"),

        # Investigation
        ("Investigation", "Why is my bill higher than usual?"),

        # Dimension queries
        ("By Region", "Show me costs by region"),
        ("Daily Breakdown", "Show me daily costs for the past week"),
    ]

    results = []

    for name, query in test_queries:
        print(f"\n\n{'#'*60}")
        print(f"TEST: {name}")
        print(f"{'#'*60}")

        try:
            start_time = datetime.now()
            response = invoke_agent(query)
            duration = (datetime.now() - start_time).total_seconds()

            results.append({
                'name': name,
                'query': query,
                'status': 'PASS' if response else 'EMPTY',
                'duration': f"{duration:.1f}s",
                'response_length': len(response)
            })

        except Exception as e:
            results.append({
                'name': name,
                'query': query,
                'status': 'FAIL',
                'error': str(e)
            })

    # Print summary
    print(f"\n\n{'='*60}")
    print("TEST RESULTS SUMMARY")
    print(f"{'='*60}")

    for r in results:
        status_icon = "✅" if r['status'] == 'PASS' else "❌"
        print(f"{status_icon} {r['name']}: {r['status']} ({r.get('duration', 'N/A')})")

    passed = sum(1 for r in results if r['status'] == 'PASS')
    print(f"\nTotal: {passed}/{len(results)} passed")


if __name__ == '__main__':
    if len(sys.argv) > 1:
        # Single query mode
        query = ' '.join(sys.argv[1:])
        invoke_agent(query)
    else:
        # Run full test suite
        run_test_suite()
```

### Step 4.2: Run Tests

```bash
# Make script executable
chmod +x scripts/04-test-agent.py

# Source environment
source scripts/env.sh

# Run full test suite
python3 scripts/04-test-agent.py

# Or run single queries
python3 scripts/04-test-agent.py "What's my AWS spend this month?"
python3 scripts/04-test-agent.py "Are there any cost anomalies?"
```

---

## Phase 5: Observability Setup

### Step 5.1: View Lambda Logs

```bash
# Tail Lambda logs
aws logs tail /aws/lambda/cost-explorer-tool --follow --region eu-central-1

# Search for errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/cost-explorer-tool \
  --filter-pattern "ERROR" \
  --region eu-central-1
```

### Step 5.2: View Agent Traces

```bash
# Get recent agent invocations (via CloudWatch)
aws logs describe-log-groups \
  --log-group-name-prefix /aws/bedrock \
  --region eu-central-1

# Enable CloudWatch logging for agent (if not auto-enabled)
# Check Bedrock console for trace details
```

### Step 5.3: Create CloudWatch Dashboard

```bash
# Create dashboard for monitoring
aws cloudwatch put-dashboard \
  --dashboard-name "CostExplainerAgent" \
  --dashboard-body '{
    "widgets": [
      {
        "type": "metric",
        "properties": {
          "title": "Lambda Invocations",
          "region": "eu-central-1",
          "metrics": [
            ["AWS/Lambda", "Invocations", "FunctionName", "cost-explorer-tool"]
          ]
        }
      },
      {
        "type": "metric",
        "properties": {
          "title": "Lambda Duration",
          "region": "eu-central-1",
          "metrics": [
            ["AWS/Lambda", "Duration", "FunctionName", "cost-explorer-tool"]
          ]
        }
      },
      {
        "type": "metric",
        "properties": {
          "title": "Lambda Errors",
          "region": "eu-central-1",
          "metrics": [
            ["AWS/Lambda", "Errors", "FunctionName", "cost-explorer-tool"]
          ]
        }
      }
    ]
  }' \
  --region eu-central-1
```

---

## Phase 6: Documentation & Learnings

**Goal:** Capture insights for future reference and team sharing

### Step 6.1: Create Learnings Document

```bash
# Create file: LEARNINGS.md
cat > LEARNINGS.md << 'EOF'
# Cost Explainer Agent - Learnings

**Date:** $(date +%Y-%m-%d)
**POC Duration:** [Fill in]
**Total Cost:** [Fill in from Cost Explorer]

---

## Executive Summary

[2-3 sentences: What did you build? Did it work? Key takeaway?]

---

## AgentCore Platform Insights

### Setup Experience

| Aspect | Observation | Rating (1-5) |
|--------|-------------|--------------|
| Documentation quality | | |
| CLI/Console experience | | |
| Error messages clarity | | |
| Time to first working agent | | |

**What was easy:**
-

**What was confusing:**
-

**Documentation gaps found:**
-

### Tool Binding (Lambda Integration)

| Aspect | Finding |
|--------|---------|
| Event structure from agent | |
| Response format expected | |
| Error handling pattern | |
| Cold start impact | |

**Key code patterns learned:**
```python
# Paste important patterns here
```

### Tracing & Observability

| Feature | Available? | Quality |
|---------|------------|---------|
| Reasoning steps visible | Yes/No | |
| Tool call parameters logged | Yes/No | |
| Token usage tracked | Yes/No | |
| Latency breakdown | Yes/No | |

**How to access traces:**
-

**What's missing:**
-

### Security Model

| Component | Role/Policy | Least Privilege Achieved? |
|-----------|-------------|---------------------------|
| Lambda execution | | Yes/No |
| Agent execution | | Yes/No |
| Cross-service access | | Yes/No |

**IAM lessons learned:**
-

### Performance Observations

| Metric | Observed Value | Acceptable? |
|--------|----------------|-------------|
| End-to-end latency | | |
| Lambda cold start | | |
| Cost Explorer API latency | | |
| Token consumption per query | | |

---

## Production Considerations

If taking this to production, would need:

### Must Have
- [ ]
- [ ]
- [ ]

### Should Have
- [ ]
- [ ]

### Nice to Have
- [ ]
- [ ]

### Estimated Effort for Production
| Item | Complexity |
|------|------------|
| | Low/Med/High |

---

## Multi-Agent Readiness

**Could this be extended to multi-agent (A2A)?**

| Consideration | Assessment |
|---------------|------------|
| Current architecture supports A2A? | |
| Effort to add second agent | |
| When would A2A be worth it? | |

---

## Cost Analysis

| Item | Cost |
|------|------|
| Bedrock/Claude usage | $ |
| Lambda invocations | $ |
| Cost Explorer API calls | $ |
| CloudWatch logs | $ |
| **Total POC cost** | $ |

**Cost per query estimate:** $

---

## Recommendations

### For This Use Case
1.
2.
3.

### For Future Agent Projects
1.
2.
3.

---

## Open Questions

- [ ]
- [ ]
- [ ]

---

*Generated as part of Cost Explainer Agent POC*
EOF

echo "LEARNINGS.md template created"
```

### Step 6.2: Capture Key Metrics

```bash
# Get actual costs for POC
echo "=== POC Cost Summary ==="

# Get Bedrock costs (if available)
aws ce get-cost-and-usage \
  --time-period Start=$(date -v-7d +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost \
  --filter '{
    "Dimensions": {
      "Key": "SERVICE",
      "Values": ["Amazon Bedrock", "AWS Lambda", "Amazon CloudWatch"]
    }
  }' \
  --query 'ResultsByTime[*].Groups[*].[Keys[0],Metrics.UnblendedCost.Amount]' \
  --output table

# Count Lambda invocations
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=cost-explorer-tool \
  --start-time $(date -v-7d -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 604800 \
  --statistics Sum \
  --region eu-central-1 \
  --query 'Datapoints[0].Sum'
```

### Step 6.3: Review Checklist

Complete this checklist before closing the POC:

```markdown
## POC Completion Checklist

### Platform Learning Objectives
- [ ] Understand agent lifecycle (create → prepare → alias → invoke)
- [ ] Understand tool binding (Lambda + OpenAPI schema)
- [ ] Explored tracing capabilities
- [ ] Documented IAM model
- [ ] Identified production gaps

### Utility Objectives
- [ ] Agent answers basic cost questions
- [ ] Agent retrieves anomalies (or correctly reports none)
- [ ] Agent provides forecasts
- [ ] Response quality is acceptable

### Documentation
- [ ] LEARNINGS.md completed
- [ ] Key code patterns captured
- [ ] Production considerations listed
- [ ] Cost analysis done

### Cleanup Decision
- [ ] Keep resources for further experimentation
- [ ] Run cleanup script to remove resources
- [ ] Keep anomaly monitor regardless
```

### Step 6.4: Share Findings (Optional)

```bash
# If sharing with team, create summary
cat > POC_SUMMARY.md << 'EOF'
# Cost Explainer Agent POC - Executive Summary

## What We Built
A Bedrock AgentCore agent that answers natural language questions about AWS costs.

## Key Findings
1. [Finding 1]
2. [Finding 2]
3. [Finding 3]

## Recommendation
[Go/No-Go for production development]

## Next Steps
- [ ] [Action item 1]
- [ ] [Action item 2]
EOF
```

---

## Phase 7: Cleanup

```bash
# scripts/99-cleanup.sh

#!/bin/bash
set -e
source scripts/env.sh

echo "⚠️  This will delete all POC resources. Press Ctrl+C to cancel."
echo ""
echo "Will DELETE:"
echo "  - Bedrock Agent and Alias"
echo "  - Lambda function"
echo "  - IAM roles and policies"
echo "  - CloudWatch logs and dashboard"
echo ""
echo "Will KEEP:"
echo "  - Anomaly Monitor (useful for future, costs nothing)"
echo ""
read -p "Type 'DELETE' to confirm: " confirm

if [ "$confirm" != "DELETE" ]; then
  echo "Cancelled."
  exit 1
fi

echo "Cleaning up Cost Explainer Agent POC..."

# Delete Agent Alias
echo "Deleting agent alias..."
aws bedrock-agent delete-agent-alias \
  --agent-id $AGENT_ID \
  --agent-alias-id $ALIAS_ID \
  --region $AWS_REGION || true

# Delete Agent
echo "Deleting agent..."
aws bedrock-agent delete-agent \
  --agent-id $AGENT_ID \
  --region $AWS_REGION || true

# Delete Lambda
echo "Deleting Lambda function..."
aws lambda delete-function \
  --function-name $LAMBDA_FUNCTION_NAME \
  --region $AWS_REGION || true

# Delete IAM Role Policies
echo "Deleting IAM policies..."
aws iam delete-role-policy \
  --role-name $LAMBDA_ROLE_NAME \
  --policy-name CostExplorerToolPolicy || true

aws iam delete-role-policy \
  --role-name $AGENT_ROLE_NAME \
  --policy-name CostAgentPolicy || true

# Delete IAM Roles
echo "Deleting IAM roles..."
aws iam delete-role --role-name $LAMBDA_ROLE_NAME || true
aws iam delete-role --role-name $AGENT_ROLE_NAME || true

# Delete CloudWatch Log Groups
echo "Deleting CloudWatch logs..."
aws logs delete-log-group \
  --log-group-name /aws/lambda/cost-explorer-tool \
  --region $AWS_REGION || true

# Delete Dashboard
echo "Deleting CloudWatch dashboard..."
aws cloudwatch delete-dashboards \
  --dashboard-names CostExplainerAgent \
  --region $AWS_REGION || true

echo ""
echo "✅ Cleanup complete."
echo ""
echo "Note: Anomaly Monitor was kept. To delete it manually:"
echo "  aws ce delete-anomaly-monitor --monitor-arn <ARN>"
```

---

## Test Queries

| Category | Query | Tests |
|----------|-------|-------|
| **Basic** | "What's my AWS spend this month?" | Total + breakdown |
| **Basic** | "What's my most expensive service?" | Top service identification |
| **Comparison** | "How does this month compare to last month?" | Period delta + % |
| **Comparison** | "Show me daily costs for the past week" | Daily granularity |
| **Dimension** | "Show me costs by region" | Region breakdown |
| **Dimension** | "Break down EC2 by instance type" | Instance type grouping |
| **Anomaly** | "Are there any cost anomalies?" | Anomaly list + root causes |
| **Anomaly** | "Any unusual spending this week?" | Recent spike detection |
| **Forecast** | "What will I spend next month?" | Forecast retrieval |
| **Investigation** | "Why did my bill increase?" | Multi-step reasoning |
| **Edge Case** | "What about costs from 3 months ago?" | Historical range |

---

## Approval Checklist

Before proceeding, please confirm:

- [ ] Frankfurt region (eu-central-1) is correct
- [ ] Manual CLI approach is acceptable
- [ ] Lambda code structure looks right
- [ ] Agent instructions capture the desired behavior
- [ ] Test queries cover your use cases
- [ ] Cleanup script is sufficient

---

*Awaiting approval to proceed with implementation.*
