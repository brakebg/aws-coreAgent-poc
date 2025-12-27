# AWS AgentCore POC - Cost Explainer Agent

A proof-of-concept single-agent system using AWS Bedrock AgentCore to answer natural language questions about AWS costs and detect anomalies.

## Objective

**Primary:** Hands-on learning of AWS Bedrock AgentCore capabilities (traceability, observability, security, production-readiness)

**Secondary:** Practical tool for detecting cost spikes in company test AWS accounts

## Architecture

```
User (CLI) → Bedrock AgentCore → Lambda Tool → Cost Explorer API
                   │
            Claude Sonnet 4
```

## Features

- Natural language queries about AWS spending
- Cost comparison across time periods
- ML-based anomaly detection with root cause analysis
- Cost forecasting

## Documentation

| Document | Description |
|----------|-------------|
| [PRD.md](PRD.md) | Product Requirements Document |
| [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) | Detailed implementation plan with infrastructure diagrams |
| [TICKETS.md](TICKETS.md) | Execution tickets for step-by-step implementation |

## Project Structure

```
aws-coreAgent-poc/
├── infrastructure/          # IAM policies
├── lambda/                  # Lambda function code
├── agent/                   # Agent instructions & schema
├── scripts/                 # Deployment scripts
└── tests/                   # Test queries
```

## Status

- [x] PRD approved
- [x] Implementation plan approved
- [ ] Ticket 1: Create Anomaly Monitor
- [ ] Ticket 2-10: In progress...

## Configuration

| Setting | Value |
|---------|-------|
| Region | eu-central-1 (Frankfurt) |
| Model | Claude Sonnet 4 |
| Budget | < $30 |
# aws-coreAgent-poc
