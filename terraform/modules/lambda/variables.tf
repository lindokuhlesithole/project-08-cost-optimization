variable "app_name" {
  type = string
}

variable "recommendations_table" {
  type = string
}

variable "alert_email" {
  type    = string
  default = ""
}

variable "cpu_threshold" {
  type = number
}
