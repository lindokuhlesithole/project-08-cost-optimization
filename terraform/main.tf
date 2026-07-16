module "dynamodb" {
  source   = "./modules/dynamodb"
  app_name = var.app_name
}

module "lambda" {
  source              = "./modules/lambda"
  app_name            = var.app_name
  recommendations_table = module.dynamodb.recommendations_table
  alert_email         = var.alert_email
  cpu_threshold       = var.cpu_threshold
}

module "eventbridge" {
  source            = "./modules/eventbridge"
  app_name          = var.app_name
  analyzer_lambda   = module.lambda.analyzer_arn
  executor_lambda   = module.lambda.executor_arn
}
