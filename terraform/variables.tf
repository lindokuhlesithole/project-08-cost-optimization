variable "app_name" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "alert_email" {
  type    = string
  default = ""
}

variable "cpu_threshold" {
  type    = number
  default = 10.0
  description = "Flag EC2 if p95 CPU < this % for 7 days"
}
