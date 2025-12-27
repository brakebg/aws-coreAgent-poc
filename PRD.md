# Product Requirements Document: Cost Explainer Agent

**Version:** 1.1
**Date:** 2025-12-27
**Status:** Draft
**Owner:** Senior Engineering Manager (Hands-on POC)

---

## Executive Summary

The Cost Explainer Agent is a proof-of-concept (POC) single-agent system built on AWS Bedrock AgentCore that answers natural language questions about AWS spending and detects cost anomalies. Instead of manually navigating Cost Explorer dashboards and interpreting charts, users ask questions like "Why is my bill high?" or "Are there any cost spikes?" and receive plain English explanations with actionable insights.

### Primary Objective: Hands-on Agent Experience

This POC is a **hands-on learning exercise** for a Senior Engineering Manager to:
- Build an AI agent end-to-end (not just read about it)
- Understand AWS Bedrock AgentCore architecture and capabilities
- Evaluate production-readiness for potential team adoption
- Form informed opinions on where agents fit in platform strategy

**Key areas to explore:**
- Agent definition and configuration
- Tool binding (Lambda integration)
- Traceability and reasoning visibility
- Observability (CloudWatch, X-Ray)
- Security model (IAM roles, least privilege)
- What it takes to go from POC → production

### Secondary Objective: Practical Utility

Build something useful for **company test AWS accounts**:
- Quick detection of daily/weekly/monthly cost spikes
- Identify unusual spending patterns automatically
- Explain anomalies in plain English with root cause analysis

---

## Problem Statement

### Current Pain Points

1. **Manual Investigation Required**: Understanding AWS costs requires navigating Cost Explorer, setting filters, comparing date ranges, and drilling down through multiple views—a 10-15 minute process for basic questions.

2. **Data Without Insight**: Cost Explorer shows numbers and charts but doesn't explain *why* costs changed or *what* to do about it.

3. **Expertise Barrier**: Effective cost analysis requires knowing which dimensions to filter, what comparisons matter, and how to interpret trends.

4. **Learning Gap**: AWS Bedrock AgentCore is a new platform. Building practical applications is the best way to understand its capabilities, constraints, and operational model.

### The Opportunity

An AI agent that acts as a "cost analyst on demand"—investigating spending patterns, comparing periods, identifying anomalies, and explaining findings in conversational language.

---

## Objectives

### Primary: Platform Learning

| ID | Objective | Measurable Outcome |
|----|-----------|-------------------|
| O1 | Understand AgentCore agent lifecycle | Document agent creation, invocation, teardown |
| O2 | Master tool binding pattern | Working Lambda tool with proper IAM |
| O3 | Explore traceability features | Capture and analyze full reasoning traces |
| O4 | Evaluate observability options | CloudWatch logs, X-Ray traces configured |
| O5 | Assess production readiness | Document what production setup would require |

### Secondary: Practical Utility

| ID | Objective | Measurable Outcome |
|----|-----------|-------------------|
| O6 | Detect cost anomalies | Agent identifies daily/weekly/monthly spikes |
| O7 | Answer natural language cost questions | Agent responds to 5+ question types accurately |
| O8 | Provide faster insight than manual analysis | Response in <30 seconds vs 10-15 min manual |
| O9 | Explain anomalies with root cause | Agent provides service/region/usage breakdown |

---

## User Stories

### Persona 1: Senior Engineering Manager (POC Owner)

> "As a Senior Engineering Manager who stays hands-on with emerging technologies, I want to build a working AI agent end-to-end, so I can understand AgentCore capabilities, make informed architectural decisions for my teams, and evaluate where agents fit in our platform strategy."

**Motivations:**
- Stay current with AI/Agent technology trends
- Hands-on experience over theoretical knowledge
- Evaluate production-readiness for team adoption
- Understand operational concerns (observability, security, cost)

### Persona 2: DevOps Engineer (Company Test Accounts)

> "As a DevOps engineer managing company test AWS accounts, I want to quickly detect cost spikes without manual dashboard checks, so I can catch runaway resources before they become expensive."

### User Stories: Cost Queries

| ID | Story | Acceptance Criteria |
|----|-------|---------------------|
| US1 | As a user, I can ask "What's my total spend this month?" and get a clear answer | Agent returns total with service breakdown |
| US2 | As a user, I can ask "How does this month compare to last month?" and see the delta | Agent shows % change and top movers |
| US3 | As a user, I can ask "What's my most expensive service?" and understand why | Agent identifies top service with context |
| US4 | As a user, I can ask "Why did my bill increase?" and get root cause analysis | Agent compares periods, identifies drivers |
| US5 | As a user, I can ask "What's my forecasted spend?" and plan accordingly | Agent returns AWS forecast data |

### User Stories: Anomaly Detection

| ID | Story | Acceptance Criteria |
|----|-------|---------------------|
| US6 | As a user, I can ask "Are there any cost anomalies?" and get flagged issues | Agent retrieves and explains detected anomalies |
| US7 | As a user, I can ask "Any unusual spending this week?" and get spike analysis | Agent compares recent days to baseline |
| US8 | As a user, I see root causes for each anomaly | Agent shows service, region, usage type breakdown |

### User Stories: Platform Learning

| ID | Story | Acceptance Criteria |
|----|-------|---------------------|
| US9 | As a developer, I can see the agent's reasoning steps | Traces visible in CloudWatch/console |
| US10 | As a developer, I can observe tool invocations | X-Ray traces show Lambda calls |
| US11 | As a developer, I can verify least-privilege security | IAM roles are minimal and documented |

---

## Functional Requirements

### FR1: Natural Language Understanding

| ID | Requirement | Priority |
|----|-------------|----------|
| FR1.1 | Accept free-form English questions about AWS costs | Must Have |
| FR1.2 | Interpret intent (total spend, comparison, breakdown, forecast) | Must Have |
| FR1.3 | Handle ambiguous time ranges with sensible defaults | Should Have |

### FR2: Cost Data Retrieval

| ID | Requirement | Priority |
|----|-------------|----------|
| FR2.1 | Query Cost Explorer API for cost and usage data | Must Have |
| FR2.2 | Support filtering by service, region, time period | Must Have |
| FR2.3 | Support grouping by service, region, instance type | Must Have |
| FR2.4 | Retrieve cost forecasts | Should Have |
| FR2.5 | Compare arbitrary time periods | Must Have |

### FR2.5: Anomaly Detection

| ID | Requirement | Priority |
|----|-------------|----------|
| FR2.6 | Retrieve detected anomalies via GetAnomalies API | Must Have |
| FR2.7 | Access anomaly root causes (service, region, usage type) | Must Have |
| FR2.8 | Support anomaly lookback period (up to 90 days) | Should Have |
| FR2.9 | Report anomaly impact (expected vs actual spend) | Must Have |

### FR3: Analysis & Reasoning

| ID | Requirement | Priority |
|----|-------------|----------|
| FR3.1 | Calculate period-over-period changes (absolute and %) | Must Have |
| FR3.2 | Identify top N cost drivers | Must Have |
| FR3.3 | Detect significant changes (>10% variance) | Should Have |
| FR3.4 | Chain multiple queries to drill down | Must Have |

### FR4: Response Generation

| ID | Requirement | Priority |
|----|-------------|----------|
| FR4.1 | Generate plain English explanations | Must Have |
| FR4.2 | Include specific numbers with context | Must Have |
| FR4.3 | Provide actionable observations (not just data) | Should Have |
| FR4.4 | Format responses for CLI readability | Must Have |

### FR5: Invocation

| ID | Requirement | Priority |
|----|-------------|----------|
| FR5.1 | Invoke agent via AWS CLI | Must Have |
| FR5.2 | Invoke agent via SDK (Python/boto3) | Should Have |
| FR5.3 | Support synchronous request/response | Must Have |

---

## Non-Functional Requirements

### NFR1: Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR1.1 | End-to-end response time | < 30 seconds |
| NFR1.2 | Cost Explorer API latency tolerance | < 5 seconds per call |
| NFR1.3 | Maximum reasoning steps | 5 steps |

### NFR2: Security

| ID | Requirement | Target |
|----|-------------|--------|
| NFR2.1 | Least-privilege IAM for agent | Read-only Cost Explorer access |
| NFR2.2 | No credential exposure in logs | Verified via trace inspection |
| NFR2.3 | Agent cannot modify resources | Enforced by IAM |

### NFR3: Observability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR3.1 | All reasoning steps logged | Visible in CloudWatch |
| NFR3.2 | Tool invocations traced | X-Ray or equivalent |
| NFR3.3 | Errors captured with context | Structured logging |

### NFR4: Reliability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR4.1 | Handle Cost Explorer API errors gracefully | Retry + user message |
| NFR4.2 | Timeout handling | Configurable, default 60s |

### NFR5: Cost

| ID | Requirement | Target |
|----|-------------|--------|
| NFR5.1 | POC total cost | < $30 |
| NFR5.2 | Per-query cost | < $0.15 |

---

## Success Metrics

### Platform Learning Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| AgentCore concepts documented | 10+ findings | Written documentation |
| Traceability verified | Full reasoning chain visible | CloudWatch inspection |
| Security model understood | IAM roles documented | Architecture review |
| Production considerations listed | 5+ items | Written checklist |

### Utility Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Question types supported | 5+ distinct types | Manual test matrix |
| Anomaly detection working | Retrieves real anomalies | Test with triggered anomaly |
| Response accuracy | >90% correct | Compare to manual analysis |
| Response time | <30 seconds | Timed invocations |

---

## Assumptions & Constraints

### Assumptions

1. AWS Cost Explorer is enabled in the target account (24h activation if new)
2. Cost data has at least 1 month of history for meaningful comparisons
3. AgentCore preview is available and functional
4. Claude Sonnet model is available in Bedrock

### Constraints

1. **Cost Explorer Data Delay**: Data is 24-48 hours behind real-time
2. **API Rate Limits**: Cost Explorer has pagination and throttling limits
3. **Single Account**: No cross-account cost analysis in POC scope
4. **No Resource-Level Data**: Unless hourly/resource granularity is enabled (extra cost)
5. **Preview Limitations**: AgentCore may have undocumented constraints

### Dependencies

| Dependency | Type | Risk |
|------------|------|------|
| AWS Bedrock AgentCore | Service | Preview availability |
| Claude Sonnet on Bedrock | Model | Availability, pricing |
| Cost Explorer API | Data source | Low risk, stable |
| AWS CLI/SDK | Tooling | Low risk |

---

## Out of Scope

The following are explicitly **NOT** included in this POC:

| Item | Rationale |
|------|-----------|
| Multi-account support | Adds complexity, not needed for learning |
| Real-time cost data | Cost Explorer limitation, not solvable |
| Resource-level details (instance IDs) | Requires additional API + cost |
| CloudTrail integration (who created what) | Phase 2 enhancement |
| Automated actions/remediation | Read-only POC |
| Web UI or chat interface | CLI-first for simplicity |
| Scheduled/automated runs | Manual invocation only |
| Alerting/notifications | Not a monitoring tool |
| Historical trend analysis (>3 months) | Keep queries simple |
| Multi-agent orchestration | Phase 2 after learning basics |
| Cost allocation tags deep dive | Nice-to-have, not core |

---

## Appendix A: Sample Interactions

### Interaction 1: Basic Spend Query
```
User: "What's my AWS spend this month?"

Agent: "Your AWS spend for December 2025 is $234.56.

Breakdown by service:
• EC2: $142.30 (61%)
• RDS: $52.10 (22%)
• S3: $23.45 (10%)
• Other: $16.71 (7%)

This is 12% higher than November ($209.23)."
```

### Interaction 2: Cost Investigation
```
User: "Why did my bill go up?"

Agent: "Your December bill ($234.56) is up $25.33 (+12%) from November.

Main drivers:
1. EC2 increased $18.50 (+15%)
   - Usage in us-east-1 up significantly
   - On-Demand hours increased from 720 to 830

2. RDS increased $6.20 (+13%)
   - Storage grew from 50GB to 65GB

S3 and other services remained stable."
```

### Interaction 3: Forecast Query
```
User: "What will I spend this month?"

Agent: "Based on current usage patterns, AWS forecasts your December spend at $267.00.

This is $32 higher than your current pace suggests, likely due to:
• Month-end batch processing patterns
• Historical weekend usage spikes

You're currently at $234.56 with 4 days remaining."
```

---

## Appendix B: Technical Context (For Implementation Planning)

### AgentCore Components to Explore

1. **Agent Definition**: How to define agent, model, instructions
2. **Tool Binding**: How Lambda functions become agent tools
3. **Session Management**: Stateful vs stateless conversations
4. **Tracing**: How to view reasoning steps
5. **IAM Model**: Agent roles, tool roles, invocation roles
6. **Error Handling**: How agent handles tool failures

### Cost Explorer API Operations Needed

| Operation | Purpose |
|-----------|---------|
| `GetCostAndUsage` | Core spend data |
| `GetCostForecast` | Predicted spend |
| `GetAnomalies` | ML-detected cost anomalies |
| `GetAnomalyMonitors` | List anomaly detection monitors |

### GetAnomalies Response Structure

```json
{
  "Anomalies": [{
    "AnomalyId": "abc123",
    "AnomalyStartDate": "2024-12-20",
    "AnomalyEndDate": "2024-12-21",
    "DimensionValue": "Amazon EC2",
    "Impact": {
      "TotalActualSpend": 5000.00,
      "TotalExpectedSpend": 2000.00,
      "TotalImpact": 3000.00,
      "TotalImpactPercentage": 150.0
    },
    "RootCauses": [{
      "Service": "Amazon EC2",
      "Region": "us-east-1",
      "UsageType": "BoxUsage:c5.4xlarge"
    }]
  }]
}
```

### Dimensions for Grouping/Filtering

- SERVICE
- REGION
- INSTANCE_TYPE
- USAGE_TYPE
- LINKED_ACCOUNT (future)

### API Constraints

| Constraint | Value |
|------------|-------|
| Data delay | 24 hours |
| Anomaly history | 90 days max |
| API cost | $0.01 per request |
| Rate limit | ~100 requests/second |

---

## Appendix C: Sample Interactions (Extended)

### Interaction 4: Anomaly Detection
```
User: "Are there any cost anomalies?"

Agent: "I found 2 cost anomalies in the last 30 days:

1. **December 20-21** - EC2 spike
   • Expected: $67/day → Actual: $185/day (+176%)
   • Impact: $118 unexpected spend
   • Root cause: c5.4xlarge instances in us-east-1
   • Usage type: BoxUsage increased 3x

2. **December 15** - S3 spike
   • Expected: $12/day → Actual: $34/day (+183%)
   • Impact: $22 unexpected spend
   • Root cause: DataTransfer-Out in eu-west-1

Recommendation: Check if the EC2 instances from Dec 20 are still running."
```

### Interaction 5: Weekly Spike Check
```
User: "Any unusual spending this week?"

Agent: "Comparing this week to your 4-week average:

This week: $89.40
4-week average: $72.15
Difference: +$17.25 (+24%)

Top contributors to increase:
1. Lambda: +$8.50 (invocations up 40%)
2. EC2: +$5.20 (new t3.medium in us-west-2)
3. CloudWatch: +$3.55 (log ingestion doubled)

No anomalies flagged by AWS - this appears to be organic growth."
```

---

*End of PRD*
