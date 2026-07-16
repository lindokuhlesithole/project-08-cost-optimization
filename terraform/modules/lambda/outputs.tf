output "analyzer_arn" {
  value = aws_lambda_function.analyzer.arn
}

output "executor_arn" {
  value = aws_lambda_function.executor.arn
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
