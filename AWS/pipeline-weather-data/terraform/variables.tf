variable "github_owner" {
  type        = string
  description = "GitHub repository owner (username or organization)"
  default     = "songtoan0201"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
  default     = "aws_weather_pipeline"
}

variable "account_id" {
  type        = string
  description = "Account Id AWS"
  default     = "779854054450" // Replace with your account id
}

variable "region" {
  type        = string
  description = "Region AWS"
  default     = "us-west-1"
}

variable "lambda_function_name" {
  type        = string
  description = "Lambda function name"
  default     = "get_api_weather_data_lambda"
}

variable "pipeline_name" {
  type        = string
  description = "Name of pipeline"
  default     = "pipeline-weather-data"
}

variable "enable_codebuild_webhooks" {
  type        = bool
  description = "Enable CodeBuild webhooks (requires GitHub token setup)"
  default     = false
}

variable "enable_snowflake_integration" {
  type        = bool
  description = "Enable Snowflake integration (requires IAM user to exist first)"
  default     = true
}


///////// SNOWFLAKE VARIABLES CONNECTIONS /////////////////

variable "aws_iam_user_arn_by_snowflake" {
  type        = string
  description = "Iam user ARN by snowflake"
  default     = "arn:aws:iam::779854054450:user/BUQZDTX-QCB24090" // Replace with your Iam user ARN by snowflake
}

variable "glue_aws_external_id_by_snowflake" {
  type        = string
  description = "Glue aws external id by snowflake"
  default     = "CNB84282_SFCRole=4_heCNt9tr2SwDbkvN0EH6+K5dIaI=" // Replace with your Glue aws external id by snowflake
}

variable "storage_aws_external_id_by_snowflake" {
  type        = string
  description = "Storage aws external id by snowflake"
  default     = "CNB84282_SFCRole=4_3SAsxKLi5EQ9OvAfhOLNkhQ/ev0=" // Replace with your Storage aws external id by snowflake
}
