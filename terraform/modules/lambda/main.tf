# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.app_name}-alerts"
  tags = { Name = "${var.app_name}-alerts" }
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# IAM Role
resource "aws_iam_role" "lambda" {
  name = "${var.app_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = { Name = "${var.app_name}-lambda-role" }
}

resource "aws_iam_role_policy" "lambda" {
  name = "${var.app_name}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          "arn:aws:dynamodb:*:*:table/${var.recommendations_table}",
          "arn:aws:dynamodb:*:*:table/${var.recommendations_table}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:ModifyInstanceAttribute",
          "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
      }
    ]
  })
}

# Analyzer Lambda
resource "aws_lambda_function" "analyzer" {
  function_name = "${var.app_name}-analyzer"
  role          = aws_iam_role.lambda.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 256

  filename         = data.archive_file.analyzer.output_path
  source_code_hash = data.archive_file.analyzer.output_base64sha256

  environment {
    variables = {
      RECOMMENDATIONS_TABLE = var.recommendations_table
      SNS_TOPIC_ARN         = aws_sns_topic.alerts.arn
      CPU_THRESHOLD         = var.cpu_threshold
    }
  }

  tags = { Name = "${var.app_name}-analyzer" }
}

data "archive_file" "analyzer" {
  type        = "zip"
  output_path = "${path.module}/analyzer.zip"

  source {
    content  = <<-EOF
import json
import boto3
import os
from datetime import datetime, timedelta
from uuid import uuid4

ec2 = boto3.client('ec2')
cloudwatch = boto3.client('cloudwatch')
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

table = dynamodb.Table(os.environ['RECOMMENDATIONS_TABLE'])
sns_topic = os.environ['SNS_TOPIC_ARN']
cpu_threshold = float(os.environ['CPU_THRESHOLD'])

def lambda_handler(event, context):
    """Analyze EC2 instances and generate right-sizing recommendations"""

    recommendations = []
    instances = ec2.describe_instances(
        Filters=[{'Name': 'instance-state-name', 'Values': ['running']}]
    )

    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            instance_type = instance['InstanceType']
            tags = {t['Key']: t['Value'] for t in instance.get('Tags', [])}

            # Skip if tagged for exclusion
            if tags.get('CostOptimization') == 'Ignore':
                continue

            # Get CPU utilization for last 7 days
            end_time = datetime.utcnow()
            start_time = end_time - timedelta(days=7)

            metrics = cloudwatch.get_metric_statistics(
                Namespace='AWS/EC2',
                MetricName='CPUUtilization',
                Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
                StartTime=start_time.isoformat(),
                EndTime=end_time.isoformat(),
                Period=86400,
                Statistics=['Average']
            )

            if not metrics['Datapoints']:
                continue

            avg_cpu = sum(d['Average'] for d in metrics['Datapoints']) / len(metrics['Datapoints'])

            if avg_cpu < cpu_threshold:
                # Calculate potential savings (simplified)
                savings = estimate_savings(instance_type)
                confidence = calculate_confidence(avg_cpu)

                rec = {
                    'recommendationId': str(uuid4()),
                    'timestamp': datetime.utcnow().isoformat(),
                    'expiresAt': int((datetime.utcnow() + timedelta(days=90)).timestamp()),
                    'resourceId': instance_id,
                    'resourceType': 'EC2',
                    'currentType': instance_type,
                    'recommendedAction': 'DOWNSIZE',
                    'avgCpu': str(round(avg_cpu, 2)),
                    'estimatedSavings': str(savings),
                    'confidence': confidence,
                    'status': 'PENDING',
                    'environment': tags.get('Environment', 'unknown'),
                    'team': tags.get('Team', 'unknown')
                }

                table.put_item(Item=rec)
                recommendations.append(rec)

    # Send summary alert if recommendations found
    if recommendations:
        total_savings = sum(float(r['estimatedSavings']) for r in recommendations)
        sns.publish(
            TopicArn=sns_topic,
            Subject=f"Cost Optimization: {len(recommendations)} recommendations found",
            Message=json.dumps({
                'count': len(recommendations),
                'totalEstimatedSavings': round(total_savings, 2),
                'recommendations': [{'id': r['recommendationId'], 'instance': r['resourceId'], 'savings': r['estimatedSavings']} for r in recommendations]
            }, indent=2)
        )

    return {
        'statusCode': 200,
        'body': json.dumps({
            'analyzed': sum(len(r['Instances']) for r in instances['Reservations']),
            'recommendations': len(recommendations),
            'totalEstimatedSavings': sum(float(r['estimatedSavings']) for r in recommendations)
        })
    }

def estimate_savings(instance_type):
    """Simplified savings estimate"""
    pricing = {
        't3.micro': 8.5, 't3.small': 17.0, 't3.medium': 34.0,
        't3.large': 68.0, 't3.xlarge': 136.0,
        't2.micro': 8.5, 't2.small': 17.0, 't2.medium': 34.0
    }
    return pricing.get(instance_type, 20.0) * 0.3  # Assume 30% savings

def calculate_confidence(avg_cpu):
    if avg_cpu < 5:
        return 'HIGH'
    elif avg_cpu < 10:
        return 'MEDIUM'
    return 'LOW'
EOF
    filename = "handler.py"
  }
}

# Executor Lambda
resource "aws_lambda_function" "executor" {
  function_name = "${var.app_name}-executor"
  role          = aws_iam_role.lambda.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30

  filename         = data.archive_file.executor.output_path
  source_code_hash = data.archive_file.executor.output_base64sha256

  environment {
    variables = {
      RECOMMENDATIONS_TABLE = var.recommendations_table
    }
  }

  tags = { Name = "${var.app_name}-executor" }
}

data "archive_file" "executor" {
  type        = "zip"
  output_path = "${path.module}/executor.zip"

  source {
    content  = <<-EOF
import json
import boto3
import os
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['RECOMMENDATIONS_TABLE'])

def lambda_handler(event, context):
    """Execute approved cost optimization recommendations"""

    # Find approved recommendations
    response = table.scan(
        FilterExpression='#status = :status',
        ExpressionAttributeNames={'#status': 'status'},
        ExpressionAttributeValues={':status': 'APPROVED'}
    )

    executed = 0
    for rec in response.get('Items', []):
        # In a real scenario, this would resize the EC2 instance
        # For demo, we just mark as executed
        table.update_item(
            Key={
                'recommendationId': rec['recommendationId'],
                'timestamp': rec['timestamp']
            },
            UpdateExpression='SET #status = :status, executedAt = :time, action = :action',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': 'EXECUTED',
                ':time': datetime.utcnow().isoformat(),
                ':action': 'SIMULATED_RESIZE'
            }
        )
        executed += 1

    return {
        'statusCode': 200,
        'body': json.dumps({
            'executed': executed,
            'message': 'Approved recommendations processed'
        })
    }
EOF
    filename = "handler.py"
  }
}
