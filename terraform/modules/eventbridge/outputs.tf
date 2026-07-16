output "scheduler_rule" {
  value = aws_cloudwatch_event_rule.analyzer.name
}
