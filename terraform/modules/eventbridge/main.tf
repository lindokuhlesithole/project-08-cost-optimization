# Daily analyzer trigger (6 AM UTC)
resource "aws_cloudwatch_event_rule" "analyzer" {
  name                = "${var.app_name}-daily-analyzer"
  description         = "Trigger cost optimization analysis daily"
  schedule_expression = "cron(0 6 * * ? *)"
  tags                = { Name = "${var.app_name}-daily-analyzer" }
}

resource "aws_cloudwatch_event_target" "analyzer" {
  rule      = aws_cloudwatch_event_rule.analyzer.name
  target_id = "analyzer"
  arn       = var.analyzer_lambda
}

resource "aws_lambda_permission" "analyzer" {
  statement_id  = "AllowEventBridgeAnalyzer"
  action        = "lambda:InvokeFunction"
  function_name = var.analyzer_lambda
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.analyzer.arn
}

# Hourly executor trigger
resource "aws_cloudwatch_event_rule" "executor" {
  name                = "${var.app_name}-hourly-executor"
  description         = "Process approved recommendations hourly"
  schedule_expression = "rate(1 hour)"
  tags                = { Name = "${var.app_name}-hourly-executor" }
}

resource "aws_cloudwatch_event_target" "executor" {
  rule      = aws_cloudwatch_event_rule.executor.name
  target_id = "executor"
  arn       = var.executor_lambda
}

resource "aws_lambda_permission" "executor" {
  statement_id  = "AllowEventBridgeExecutor"
  action        = "lambda:InvokeFunction"
  function_name = var.executor_lambda
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.executor.arn
}
