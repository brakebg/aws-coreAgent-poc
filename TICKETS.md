# Cost Explainer Agent POC - Tickets

**Status:** Approved
**Execution Mode:** Sequential, each ticket reviewed before execution

---

## Ticket Overview

| # | Ticket | Phase | Deliverables |
|---|--------|-------|--------------|
| 1 | Create Anomaly Monitor | 0 | Anomaly monitor in AWS |
| 2 | Setup Environment & Project Structure | 1a | `scripts/env.sh`, folder structure |
| 3 | Create IAM Roles & Policies | 1b | 2 IAM roles, 4 policy files |
| 4 | Implement Lambda Function | 2a | `lambda_function.py` |
| 5 | Deploy Lambda & Test Directly | 2b | Deployed Lambda, test results |
| 6 | Create Agent Instructions & Schema | 3a | `agent-instructions.txt`, `openapi-schema.json` |
| 7 | Create Bedrock Agent & Bind Tool | 3b | Agent ID, Alias ID |
| 8 | Create Test Script & Run Tests | 4 | `04-test-agent.py`, test results |
| 9 | Setup Observability | 5 | CloudWatch dashboard, log queries |
| 10 | Document Learnings | 6 | `LEARNINGS.md`, `POC_SUMMARY.md` |

---

## Ticket 1: Create Anomaly Monitor

**Phase:** 0
**Goal:** Enable AWS Cost Anomaly Detection

### What will be done:
1. Check for existing anomaly monitors
2. Create `AllServicesMonitor` (DIMENSIONAL type)
3. Verify monitor creation

### Commands to execute:
```bash
# Check existing
aws ce get-anomaly-monitors --query 'AnomalyMonitors[*].MonitorName'

# Create monitor
aws ce create-anomaly-monitor \
  --anomaly-monitor '{
    "MonitorName": "AllServicesMonitor",
    "MonitorType": "DIMENSIONAL",
    "MonitorDimension": "SERVICE"
  }'

# Verify
aws ce get-anomaly-monitors --query 'AnomalyMonitors[*].[MonitorName,MonitorType]' --output table
```

### Expected output:
- Monitor ARN returned
- Monitor visible in table

### Notes:
- ML model needs ~10 days to train
- API works immediately but may return 0 anomalies initially

---

## Ticket 2: Setup Environment & Project Structure

**Phase:** 1a
**Goal:** Create project folders and environment variables

### What will be done:
1. Create folder structure
2. Create `scripts/env.sh` with variables
3. Verify AWS CLI access

### Folders to create:
```
poc-coreAgent-costanomaly/
├── infrastructure/
│   └── iam-policies/
├── lambda/
│   └── cost-explorer-tool/
├── agent/
├── scripts/
└── tests/
```

### Files to create:
```bash
# scripts/env.sh
export AWS_REGION="eu-central-1"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export LAMBDA_ROLE_NAME="cost-explorer-tool-role"
export AGENT_ROLE_NAME="cost-agent-role"
export LAMBDA_FUNCTION_NAME="cost-explorer-tool"
export AGENT_NAME="cost-explainer-agent"
```

### Verification:
```bash
source scripts/env.sh
echo "Account: $AWS_ACCOUNT_ID, Region: $AWS_REGION"
```

---

## Ticket 3: Create IAM Roles & Policies

**Phase:** 1b
**Goal:** Create IAM roles for Lambda and Agent

### What will be done:
1. Create 4 policy JSON files
2. Create Lambda execution role
3. Create Agent execution role
4. Verify roles exist

### Files to create:
- `infrastructure/iam-policies/lambda-trust-policy.json`
- `infrastructure/iam-policies/lambda-permissions-policy.json`
- `infrastructure/iam-policies/agent-trust-policy.json`
- `infrastructure/iam-policies/agent-permissions-policy.json`

### Script to create:
- `scripts/01-setup-iam.sh`

### Verification:
```bash
aws iam get-role --role-name cost-explorer-tool-role --query 'Role.Arn'
aws iam get-role --role-name cost-agent-role --query 'Role.Arn'
```

---

## Ticket 4: Implement Lambda Function

**Phase:** 2a
**Goal:** Write the Lambda function code

### What will be done:
1. Create `lambda/cost-explorer-tool/lambda_function.py`
2. Implement 3 functions:
   - `get_cost_and_usage()`
   - `get_cost_forecast()`
   - `get_anomalies()`

### File to create:
- `lambda/cost-explorer-tool/lambda_function.py` (~150 lines)

### Key features:
- Handles Bedrock Agent event structure
- Returns properly formatted responses
- Error handling included

---

## Ticket 5: Deploy Lambda & Test Directly

**Phase:** 2b
**Goal:** Deploy Lambda and verify it works without the agent

### What will be done:
1. Package Lambda (zip)
2. Deploy to AWS
3. Add Bedrock invoke permission
4. Test each action directly

### Script to create:
- `scripts/02-deploy-lambda.sh`

### Test commands:
```bash
# Test get_cost_and_usage
aws lambda invoke \
  --function-name cost-explorer-tool \
  --payload '{"apiPath": "/get_cost_and_usage", ...}' \
  /tmp/response.json

# Test get_anomalies
aws lambda invoke \
  --function-name cost-explorer-tool \
  --payload '{"apiPath": "/get_anomalies", ...}' \
  /tmp/response.json
```

### Expected output:
- Lambda function created
- Test invocations return cost data

---

## Ticket 6: Create Agent Instructions & OpenAPI Schema

**Phase:** 3a
**Goal:** Define how the agent behaves and what tools it has

### What will be done:
1. Create agent instructions (system prompt)
2. Create OpenAPI schema for tools

### Files to create:
- `agent/agent-instructions.txt` (~40 lines)
- `agent/openapi-schema.json` (~150 lines)

### Key content:
- Instructions tell agent how to respond
- Schema defines 3 API endpoints with parameters

---

## Ticket 7: Create Bedrock Agent & Bind Tool

**Phase:** 3b
**Goal:** Create the agent in AWS and connect it to Lambda

### What will be done:
1. Create agent via CLI
2. Create action group with Lambda binding
3. Prepare agent
4. Create alias for invocation
5. Save Agent ID and Alias ID

### Script to create:
- `scripts/03-create-agent.sh`

### Expected output:
```
Agent ID: XXXXXXXXXX
Alias ID: XXXXXXXXXX
```

### Verification:
```bash
aws bedrock-agent get-agent --agent-id $AGENT_ID --query 'agent.agentStatus'
```

---

## Ticket 8: Create Test Script & Run Test Suite

**Phase:** 4
**Goal:** Verify the agent answers all test queries correctly

### What will be done:
1. Create Python test script
2. Run 11 test queries
3. Record results

### Script to create:
- `scripts/04-test-agent.py` (~100 lines)

### Test queries:
1. "What's my AWS spend this month?"
2. "What's my most expensive service?"
3. "How does this month compare to last month?"
4. "Show me daily costs for the past week"
5. "Show me costs by region"
6. "Break down EC2 by instance type"
7. "Are there any cost anomalies?"
8. "Any unusual spending this week?"
9. "What will I spend next month?"
10. "Why did my bill increase?"
11. "What about costs from 3 months ago?"

### Expected output:
- Pass/Fail for each query
- Response times logged

---

## Ticket 9: Setup Observability

**Phase:** 5
**Goal:** Enable visibility into agent behavior

### What will be done:
1. Verify Lambda logs are flowing
2. Create CloudWatch dashboard
3. Document how to access agent traces

### Commands:
```bash
# Tail logs
aws logs tail /aws/lambda/cost-explorer-tool --follow

# Create dashboard
aws cloudwatch put-dashboard --dashboard-name "CostExplainerAgent" ...
```

### Deliverables:
- Dashboard URL
- Log query examples
- Trace access instructions

---

## Ticket 10: Document Learnings

**Phase:** 6
**Goal:** Capture insights from the POC

### What will be done:
1. Create `LEARNINGS.md` from template
2. Fill in observations
3. Create `POC_SUMMARY.md` for sharing
4. Capture cost metrics

### Files to create/complete:
- `LEARNINGS.md`
- `POC_SUMMARY.md`

### Key sections to document:
- Setup experience
- Tool binding patterns
- Tracing capabilities
- Security model
- Performance observations
- Production considerations
- Multi-agent readiness

---

## Execution Process

For each ticket:

1. **I present** the ticket details and files to create
2. **You review** and approve or request changes
3. **I execute** the approved work
4. **We verify** the results together
5. **Move to next** ticket

---

**Ready to start with Ticket 1: Create Anomaly Monitor?**
