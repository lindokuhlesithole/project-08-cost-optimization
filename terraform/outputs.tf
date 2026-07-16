output "recommendations_table" {
  value = module.dynamodb.recommendations_table
}

output "analyzer_lambda" {
  value = module.lambda.analyzer_arn
}

output "executor_lambda" {
  value = module.lambda.executor_arn
}

output "sns_topic_arn" {
  value = module.lambda.sns_topic_arn
}

output "scheduler_rule" {
  value = module.eventbridge.scheduler_rule
}
