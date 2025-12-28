"""
Cost Explorer Tool Lambda Function
Provides cost data to Bedrock Agent via 3 actions:
- get_cost_and_usage: Current and historical spending
- get_cost_forecast: Predicted future spending
- get_anomalies: ML-detected cost spikes
"""

import json
import boto3
from datetime import datetime, timedelta
from typing import Any

# Initialize Cost Explorer client (always uses us-east-1)
ce_client = boto3.client('ce', region_name='us-east-1')


def lambda_handler(event: dict, context: Any) -> dict:
    """
    Main handler for Bedrock Agent invocations.
    Routes to appropriate action based on apiPath.
    """
    print(f"Received event: {json.dumps(event)}")

    try:
        # Extract action from apiPath
        api_path = event.get('apiPath', '')
        action = api_path.strip('/').replace('-', '_')

        # Extract parameters into a dict
        params = {}
        for param in event.get('parameters', []):
            params[param['name']] = param['value']

        # Route to appropriate handler
        if action == 'get_cost_and_usage':
            result = get_cost_and_usage(params)
        elif action == 'get_cost_forecast':
            result = get_cost_forecast(params)
        elif action == 'get_anomalies':
            result = get_anomalies(params)
        else:
            result = {"error": f"Unknown action: {action}"}

        # Format response for Bedrock Agent
        return format_response(event, result)

    except Exception as e:
        print(f"Error: {str(e)}")
        return format_response(event, {"error": str(e)})


def get_cost_and_usage(params: dict) -> dict:
    """
    Get cost and usage data for a time period.

    Parameters:
    - start_date: Start date (YYYY-MM-DD), defaults to first of current month
    - end_date: End date (YYYY-MM-DD), defaults to today
    - group_by: Dimension to group by (SERVICE, REGION, INSTANCE_TYPE), defaults to SERVICE
    - granularity: DAILY or MONTHLY, defaults to MONTHLY
    """
    today = datetime.now()
    first_of_month = today.replace(day=1).strftime('%Y-%m-%d')

    start_date = params.get('start_date', first_of_month)
    end_date = params.get('end_date', today.strftime('%Y-%m-%d'))
    group_by = params.get('group_by', 'SERVICE')
    granularity = params.get('granularity', 'MONTHLY')

    response = ce_client.get_cost_and_usage(
        TimePeriod={
            'Start': start_date,
            'End': end_date
        },
        Granularity=granularity,
        Metrics=['UnblendedCost'],
        GroupBy=[
            {'Type': 'DIMENSION', 'Key': group_by}
        ]
    )

    # Process results
    results = []
    total = 0.0

    for time_period in response.get('ResultsByTime', []):
        period_start = time_period['TimePeriod']['Start']
        period_end = time_period['TimePeriod']['End']

        for group in time_period.get('Groups', []):
            dimension_value = group['Keys'][0]
            amount = float(group['Metrics']['UnblendedCost']['Amount'])
            total += amount

            results.append({
                'period': f"{period_start} to {period_end}",
                group_by.lower(): dimension_value,
                'amount': f"${amount:.2f}"
            })

    return {
        'start_date': start_date,
        'end_date': end_date,
        'group_by': group_by,
        'granularity': granularity,
        'total': f"${total:.2f}",
        'breakdown': sorted(results, key=lambda x: float(x['amount'].replace('$', '')), reverse=True)
    }


def get_cost_forecast(params: dict) -> dict:
    """
    Get cost forecast for future period.

    Parameters:
    - start_date: Forecast start (YYYY-MM-DD), defaults to tomorrow
    - end_date: Forecast end (YYYY-MM-DD), defaults to end of next month
    - granularity: DAILY or MONTHLY, defaults to MONTHLY
    """
    today = datetime.now()
    tomorrow = (today + timedelta(days=1)).strftime('%Y-%m-%d')

    # Default to end of next month
    next_month = today.replace(day=28) + timedelta(days=4)
    end_of_next_month = (next_month.replace(day=1) + timedelta(days=32)).replace(day=1) - timedelta(days=1)

    start_date = params.get('start_date', tomorrow)
    end_date = params.get('end_date', end_of_next_month.strftime('%Y-%m-%d'))
    granularity = params.get('granularity', 'MONTHLY')

    response = ce_client.get_cost_forecast(
        TimePeriod={
            'Start': start_date,
            'End': end_date
        },
        Metric='UNBLENDED_COST',
        Granularity=granularity
    )

    total = float(response.get('Total', {}).get('Amount', 0))

    forecasts = []
    for period in response.get('ForecastResultsByTime', []):
        forecasts.append({
            'period': f"{period['TimePeriod']['Start']} to {period['TimePeriod']['End']}",
            'mean': f"${float(period['MeanValue']):.2f}",
            'low': f"${float(period.get('PredictionIntervalLowerBound', 0)):.2f}",
            'high': f"${float(period.get('PredictionIntervalUpperBound', 0)):.2f}"
        })

    return {
        'forecast_period': f"{start_date} to {end_date}",
        'granularity': granularity,
        'total_forecast': f"${total:.2f}",
        'breakdown': forecasts
    }


def get_anomalies(params: dict) -> dict:
    """
    Get detected cost anomalies.

    Parameters:
    - lookback_days: Number of days to look back (default 30, max 90)
    - monitor_arn: Specific monitor ARN (optional, uses first available if not specified)
    """
    lookback_days = int(params.get('lookback_days', 30))
    monitor_arn = params.get('monitor_arn')

    # Calculate date range
    today = datetime.now()
    start_date = (today - timedelta(days=lookback_days)).strftime('%Y-%m-%d')
    end_date = today.strftime('%Y-%m-%d')

    # If no monitor ARN provided, get the first available
    if not monitor_arn:
        monitors = ce_client.get_anomaly_monitors()
        if monitors.get('AnomalyMonitors'):
            monitor_arn = monitors['AnomalyMonitors'][0]['MonitorArn']
        else:
            return {
                'error': 'No anomaly monitors found. Create one first.',
                'anomalies': []
            }

    response = ce_client.get_anomalies(
        MonitorArn=monitor_arn,
        DateInterval={
            'StartDate': start_date,
            'EndDate': end_date
        }
    )

    anomalies = []
    for anomaly in response.get('Anomalies', []):
        impact = anomaly.get('Impact', {})
        root_causes = []

        for rc in anomaly.get('RootCauses', []):
            root_causes.append({
                'service': rc.get('Service', 'Unknown'),
                'region': rc.get('Region', 'Unknown'),
                'usage_type': rc.get('UsageType', 'Unknown')
            })

        anomalies.append({
            'anomaly_id': anomaly.get('AnomalyId'),
            'start_date': anomaly.get('AnomalyStartDate'),
            'end_date': anomaly.get('AnomalyEndDate'),
            'dimension': anomaly.get('DimensionValue', 'Unknown'),
            'expected_spend': f"${float(impact.get('TotalExpectedSpend', 0)):.2f}",
            'actual_spend': f"${float(impact.get('TotalActualSpend', 0)):.2f}",
            'impact': f"${float(impact.get('TotalImpact', 0)):.2f}",
            'impact_percentage': f"{float(impact.get('TotalImpactPercentage', 0)):.1f}%",
            'root_causes': root_causes
        })

    return {
        'lookback_period': f"{start_date} to {end_date}",
        'monitor_arn': monitor_arn,
        'anomaly_count': len(anomalies),
        'anomalies': anomalies
    }


def format_response(event: dict, body: dict) -> dict:
    """
    Format response for Bedrock Agent.
    """
    return {
        'messageVersion': '1.0',
        'response': {
            'actionGroup': event.get('actionGroup', 'cost-explorer-actions'),
            'apiPath': event.get('apiPath', ''),
            'httpMethod': event.get('httpMethod', 'GET'),
            'httpStatusCode': 200 if 'error' not in body else 400,
            'responseBody': {
                'application/json': {
                    'body': json.dumps(body)
                }
            }
        }
    }
