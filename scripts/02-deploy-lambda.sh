#!/bin/bash
# Ticket 5: Deploy Lambda Function and Test
#
# This script:
# 1. Packages the Lambda code
# 2. Deploys to AWS (creates or updates)
# 3. Adds Bedrock invoke permission
# 4. Tests all 3 actions

set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

LAMBDA_DIR="$SCRIPT_DIR/../lambda/cost-explorer-tool"
DEPLOY_ZIP="$LAMBDA_DIR/deploy.zip"

echo "=========================================="
echo "Lambda Deployment"
echo "=========================================="
echo "Function: $LAMBDA_FUNCTION_NAME"
echo "Region:   $AWS_REGION"
echo "Role:     $LAMBDA_ROLE_NAME"
echo ""

# ==========================================
# Step 1: Package Lambda
# ==========================================
echo "[1/4] Packaging Lambda function..."

cd "$LAMBDA_DIR"
rm -f deploy.zip
zip -j deploy.zip lambda_function.py

echo "  Created: deploy.zip"
echo ""

# ==========================================
# Step 2: Deploy Lambda
# ==========================================
echo "[2/4] Deploying Lambda function..."

ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${LAMBDA_ROLE_NAME}"

# Check if function exists
if aws lambda get-function --function-name "$LAMBDA_FUNCTION_NAME" --region "$AWS_REGION" 2>/dev/null; then
    echo "  Function exists, updating code..."
    aws lambda update-function-code \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --zip-file fileb://deploy.zip \
        --region "$AWS_REGION"
else
    echo "  Creating new function..."
    aws lambda create-function \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --runtime python3.12 \
        --role "$ROLE_ARN" \
        --handler lambda_function.lambda_handler \
        --zip-file fileb://deploy.zip \
        --timeout 30 \
        --memory-size 256 \
        --region "$AWS_REGION" \
        --description "Cost Explorer tool for Bedrock Agent POC"
fi

# Wait for function to be active
echo "  Waiting for function to be active..."
aws lambda wait function-active --function-name "$LAMBDA_FUNCTION_NAME" --region "$AWS_REGION"

echo "  Done."
echo ""

# ==========================================
# Step 3: Add Bedrock Permission
# ==========================================
echo "[3/4] Adding Bedrock invoke permission..."

# Remove existing permission if present (ignore errors)
aws lambda remove-permission \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --statement-id AllowBedrockInvoke \
    --region "$AWS_REGION" 2>/dev/null || true

# Add permission
aws lambda add-permission \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --statement-id AllowBedrockInvoke \
    --action lambda:InvokeFunction \
    --principal bedrock.amazonaws.com \
    --region "$AWS_REGION"

echo "  Done."
echo ""

# ==========================================
# Step 4: Test Actions
# ==========================================
echo "[4/4] Testing Lambda actions..."
echo ""

TEST_OUTPUT="/tmp/lambda-test-response.json"

# Test 1: get_cost_and_usage
echo "  Test 1: get_cost_and_usage"
aws lambda invoke \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --region "$AWS_REGION" \
    --payload '{"apiPath": "/get_cost_and_usage", "parameters": [{"name": "group_by", "value": "SERVICE"}]}' \
    --cli-binary-format raw-in-base64-out \
    "$TEST_OUTPUT" > /dev/null

echo "  Response:"
cat "$TEST_OUTPUT" | python3 -c "import sys,json; r=json.load(sys.stdin); b=json.loads(r['response']['responseBody']['application/json']['body']); print(json.dumps(b, indent=2))"
echo ""

# Test 2: get_anomalies
echo "  Test 2: get_anomalies"
aws lambda invoke \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --region "$AWS_REGION" \
    --payload '{"apiPath": "/get_anomalies", "parameters": [{"name": "lookback_days", "value": "30"}]}' \
    --cli-binary-format raw-in-base64-out \
    "$TEST_OUTPUT" > /dev/null

echo "  Response:"
cat "$TEST_OUTPUT" | python3 -c "import sys,json; r=json.load(sys.stdin); b=json.loads(r['response']['responseBody']['application/json']['body']); print(json.dumps(b, indent=2))"
echo ""

# Test 3: get_cost_forecast
echo "  Test 3: get_cost_forecast"
aws lambda invoke \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --region "$AWS_REGION" \
    --payload '{"apiPath": "/get_cost_forecast", "parameters": []}' \
    --cli-binary-format raw-in-base64-out \
    "$TEST_OUTPUT" > /dev/null

echo "  Response:"
cat "$TEST_OUTPUT" | python3 -c "import sys,json; r=json.load(sys.stdin); b=json.loads(r['response']['responseBody']['application/json']['body']); print(json.dumps(b, indent=2))"
echo ""

# Cleanup
rm -f "$TEST_OUTPUT"

# ==========================================
# Summary
# ==========================================
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="

LAMBDA_ARN=$(aws lambda get-function --function-name "$LAMBDA_FUNCTION_NAME" --region "$AWS_REGION" --query 'Configuration.FunctionArn' --output text)

echo ""
echo "Lambda ARN: $LAMBDA_ARN"
echo ""
echo "View in console:"
echo "  https://${AWS_REGION}.console.aws.amazon.com/lambda/home?region=${AWS_REGION}#/functions/${LAMBDA_FUNCTION_NAME}"
echo ""
echo "View logs:"
echo "  aws logs tail /aws/lambda/${LAMBDA_FUNCTION_NAME} --region ${AWS_REGION} --follow"
echo ""
echo "Next: Run Ticket 6 to create Agent instructions and schema."
