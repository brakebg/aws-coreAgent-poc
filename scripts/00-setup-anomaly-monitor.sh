#!/bin/bash
# Ticket 1: Setup AWS Cost Anomaly Monitor
# This script creates a DIMENSIONAL anomaly monitor for all AWS services
#
# Prerequisites:
# - AWS CLI configured with appropriate credentials
# - Cost Explorer must be enabled in the AWS account
#
# Note: The ML model needs ~10 days to train for accurate detection
#       API works immediately but may return 0 anomalies initially

set -e

echo "=========================================="
echo "AWS Cost Anomaly Monitor Setup"
echo "=========================================="

# Step 1: Check for existing anomaly monitors
echo ""
echo "[Step 1] Checking for existing anomaly monitors..."
echo ""

EXISTING_MONITORS=$(aws ce get-anomaly-monitors \
    --query 'AnomalyMonitors[*].MonitorName' \
    --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_MONITORS" ]; then
    echo "Found existing monitors:"
    aws ce get-anomaly-monitors \
        --query 'AnomalyMonitors[*].[MonitorName,MonitorType,MonitorArn]' \
        --output table
    echo ""
    echo "If 'AllServicesMonitor' already exists, you can skip creation."
    read -p "Continue with creating a new monitor? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        echo "Skipping monitor creation."
        exit 0
    fi
else
    echo "No existing anomaly monitors found."
fi

# Step 2: Create the anomaly monitor
echo ""
echo "[Step 2] Creating 'AllServicesMonitor' (DIMENSIONAL type)..."
echo ""

MONITOR_RESPONSE=$(aws ce create-anomaly-monitor \
    --anomaly-monitor '{
        "MonitorName": "AllServicesMonitor",
        "MonitorType": "DIMENSIONAL",
        "MonitorDimension": "SERVICE"
    }' \
    --output json)

MONITOR_ARN=$(echo "$MONITOR_RESPONSE" | grep -o '"MonitorArn": "[^"]*"' | cut -d'"' -f4)

echo "Monitor created successfully!"
echo "Monitor ARN: $MONITOR_ARN"

# Step 3: Verify creation
echo ""
echo "[Step 3] Verifying monitor creation..."
echo ""

aws ce get-anomaly-monitors \
    --query 'AnomalyMonitors[*].[MonitorName,MonitorType,MonitorArn]' \
    --output table

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Notes:"
echo "- The ML model needs approximately 10 days to train"
echo "- During training, GetAnomalies API may return 0 results"
echo "- Once trained, anomalies will be detected automatically"
echo ""
echo "To check for anomalies later, run:"
echo "  aws ce get-anomalies --monitor-arn \"$MONITOR_ARN\" --date-interval Start=$(date -v-30d +%Y-%m-%d),End=$(date +%Y-%m-%d)"
echo ""
