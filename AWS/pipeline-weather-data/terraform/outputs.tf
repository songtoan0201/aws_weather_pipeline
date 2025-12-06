output "datalake_bucket_name" {
  description = "Name of the S3 bucket for data lake"
  value       = aws_s3_bucket.weather_datalake.id
}

output "scripts_bucket_name" {
  description = "Name of the S3 bucket for scripts"
  value       = aws_s3_bucket.weather_datalake_scripts.id
}

output "glue_database_name" {
  description = "Name of the Glue database"
  value       = aws_glue_catalog_database.warehouse_weather_data.name
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = var.lambda_function_name
}

output "glue_job_name" {
  description = "Name of the Glue job"
  value       = "transform-weather-data"
}

