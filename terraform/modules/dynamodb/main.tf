resource "aws_dynamodb_table" "recommendations" {
  name         = "${var.app_name}-recommendations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "recommendationId"
  range_key    = "timestamp"

  attribute {
    name = "recommendationId"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "resourceId"
    type = "S"
  }

  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "resource-index"
    hash_key        = "resourceId"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  tags = { Name = "${var.app_name}-recommendations" }
}
