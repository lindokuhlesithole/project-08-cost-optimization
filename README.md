# AWS Cost Optimization & EC2 Right-Sizing Automation

An intelligent, event-driven cost optimization platform that analyzes EC2 instances via CloudWatch metrics, identifies underutilized resources, and generates right-sizing recommendations with approval workflows.

## Architecture

```
EventBridge (Daily 6AM) → Lambda Analyzer → CloudWatch Metrics → DynamoDB → SNS Alerts
                                    ↓
                              Lambda Executor (Hourly)
```

| Stage | Action |
|-------|--------|
| **Detect** | EventBridge triggers analyzer daily |
| **Analyze** | Lambda queries CloudWatch CPU metrics for all EC2 instances |
| **Score** | Instances with < 10% CPU flagged for downsizing |
| **Store** | Recommendations saved in DynamoDB with 90-day TTL |
| **Alert** | SNS sends summary of findings |
| **Execute** | Hourly Lambda processes approved recommendations |

## Infrastructure

| Component | Technology |
|-----------|------------|
| **Scheduling** | Amazon EventBridge |
| **Analysis** | AWS Lambda (Python 3.11) |
| **Metrics** | Amazon CloudWatch |
| **Data Store** | DynamoDB (Pay-per-request + TTL) |
| **Alerting** | Amazon SNS |
| **IaC** | Terraform |

## Deployment

```bash
cd terraform
terraform init
terraform apply
```

## Test the Analyzer

```bash
# Invoke manually
aws lambda invoke   --function-name costopt2026-analyzer   --payload '{}'   --region eu-north-1   response.json

# Check DynamoDB
aws dynamodb scan --table-name costopt2026-recommendations --region eu-north-1
```

## Components

### Analyzer Lambda
- Scans all running EC2 instances
- Retrieves 7-day average CPU from CloudWatch
- Skips instances tagged `CostOptimization: Ignore`
- Generates recommendations with confidence scores
- Stores in DynamoDB with 90-day TTL
- Sends SNS alert with summary

### Executor Lambda
- Runs hourly via EventBridge
- Processes recommendations with `APPROVED` status
- Simulates EC2 resize (demo-safe)
- Updates DynamoDB with execution status

### DynamoDB Table
- `recommendations` — All findings with status index
- GSI on `status` for querying pending items
- GSI on `resourceId` for per-instance history
- TTL auto-expires after 90 days

## Cost

| Component | Monthly Cost |
|-----------|-------------|
| Lambda | ~$2 |
| DynamoDB | ~$3 |
| SNS | ~$1 |
| CloudWatch API | ~$1 |
| **Total** | **~$7/month** |

## Cleanup

```bash
terraform destroy -auto-approve
```## Author

**Lindokuhle Sithole** - *Cloud Engineer | Cloud DevOps Engineer | Cloud Security Specialist*

Based in Bremen, Germany. BSc Mathematical Science from the University of the Witwatersrand. 5x AWS Certified (Solutions Architect Professional, Security Specialty, CloudOps Engineer Associate, Solutions Architect Associate, Cloud Practitioner) plus CompTIA Security+.

- **LinkedIn:** [linkedin.com/in/lindokuhle-sithole-bb701b19a](https://www.linkedin.com/in/lindokuhle-sithole-bb701b19a)
- **GitHub:** [github.com/lindokuhlesithole](https://github.com/lindokuhlesithole)
- **Email:** sitholelindokuhle371@gmail.com