# Weather Data Pipeline - Setup and Run Guide

## Project Overview

This is an end-to-end data engineering pipeline that:
1. **Extracts** weather data from WeatherAPI using AWS Lambda
2. **Transforms** raw data using AWS Glue (PySpark) into Apache Iceberg tables
3. **Loads** data into Snowflake for analytics and visualization
4. **Orchestrates** the entire pipeline using Apache Airflow

## Architecture Components

- **Apache Airflow**: Orchestrates the pipeline (runs locally via Docker)
- **AWS Lambda**: Fetches weather data from external API and stores in S3
- **AWS Glue**: Processes raw JSON data and creates Iceberg tables
- **S3**: Data lake storage (raw and processed data)
- **Snowflake**: Data warehouse for BI analysis

---

## Prerequisites

### Required Software
1. **Docker** and **Docker Compose** (for Airflow)
2. **Terraform** (v1.0+) for infrastructure provisioning
3. **AWS CLI** configured with appropriate credentials
4. **Python 3.11+** (for local testing)
5. **Git** (for CodeBuild integration)

### Required AWS Resources
- AWS Account with appropriate permissions
- AWS credentials configured (`aws configure` or environment variables)
- Access to create: S3 buckets, Lambda functions, Glue jobs, IAM roles, CodeBuild projects

### Required External Services
- **WeatherAPI Account**: Get API key from https://www.weatherapi.com/
- **Snowflake Account** (optional, for final data warehouse)
- **GitHub Repository** (for CodeBuild CI/CD, optional)

---

## Step-by-Step Setup Instructions

### Step 1: Configure Terraform Variables

Edit `/terraform/variables.tf` and update the following:

```hcl
variable "account_id" {
  default = "YOUR_AWS_ACCOUNT_ID"  # Replace xxxxxxxxx
}

variable "region" {
  default = "us-west-1"  # Or your preferred region
}

variable "github_owner" {
  default = "YOUR_GITHUB_USERNAME"  # For CodeBuild
}

variable "github_repo" {
  default = "YOUR_REPO_NAME"  # For CodeBuild
}

# Snowflake integration (if using)
variable "aws_iam_user_arn_by_snowflake" {
  default = "arn:aws:iam::ACCOUNT_ID:user/YOUR_SNOWFLAKE_USER"
}

variable "glue_aws_external_id_by_snowflake" {
  default = "YOUR_SNOWFLAKE_EXTERNAL_ID"
}

variable "storage_aws_external_id_by_snowflake" {
  default = "YOUR_SNOWFLAKE_STORAGE_EXTERNAL_ID"
}
```

**📖 How to get these Snowflake values?** See [SNOWFLAKE_SETUP.md](./SNOWFLAKE_SETUP.md) for detailed step-by-step instructions.

**Note**: The provider region in `provider.tf` is set to `us-west-1`, but variables default to `us-west-1`. Make sure they match!

### Step 2: Update Lambda Buildspec Configuration

Edit `/lambda/buildspec.yml`:

```yaml
LAMBDA_ROLE: "arn:aws:iam::YOUR_ACCOUNT_ID:role/lambda-execution-role"
```

### Step 3: Update Glue Job Configuration

Edit `/glue/transform-weather-data/glue_job_config.json`:

```json
{
  "Role": "arn:aws:iam::YOUR_ACCOUNT_ID:role/glue_role",
  ...
}
```

### Step 4: Deploy AWS Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Apply infrastructure (creates S3 buckets, IAM roles, Glue database, etc.)
terraform apply
```

**What gets created:**
- S3 buckets: `weather-datalake-projects` and `weather-datalake-projects-scripts`
- IAM roles: `glue_role`, `lambda-execution-role`, `codebuild_role`
- Glue database: `warehouse_weather_data`
- CodeBuild projects for Lambda and Glue deployment
- Uploads `dim_locations.json` to S3

### Step 5: Deploy Lambda Function

**Option A: Using CodeBuild (CI/CD)**
- Push code to GitHub
- CodeBuild automatically deploys Lambda on push to `lambda/` folder

**Option B: Manual Deployment**
```bash
cd lambda

# Install dependencies
pip install -r requirements.txt -t .

# Create deployment package
zip -r lambda.zip .

# Upload to S3 (or use AWS CLI)
aws s3 cp lambda.zip s3://weather-datalake-projects-scripts/pipeline-weather-data/lambda/lambda.zip

# Create/update Lambda function
aws lambda create-function \
  --function-name get_api_weather_data_lambda \
  --runtime python3.11 \
  --role arn:aws:iam::YOUR_ACCOUNT_ID:role/lambda-execution-role \
  --handler get-data-api.lambda_handler \
  --code S3Bucket=weather-datalake-projects-scripts,S3Key=pipeline-weather-data/lambda/lambda.zip \
  --timeout 900 \
  --memory-size 512
```

### Step 6: Deploy Glue Job

**Option A: Using CodeBuild (CI/CD)**
- Push code to GitHub
- CodeBuild automatically deploys Glue job on push to `glue/transform-weather-data/` folder

**Option B: Manual Deployment**
```bash
cd glue/transform-weather-data

# Upload scripts to S3
aws s3 cp --recursive . s3://weather-datalake-projects-scripts/pipeline-weather-data/glue/transform-weather-data/

# Create Glue job
aws glue create-job \
  --name transform-weather-data \
  --role arn:aws:iam::YOUR_ACCOUNT_ID:role/glue_role \
  --command '{"Name":"glueetl","ScriptLocation":"s3://weather-datalake-projects-scripts/pipeline-weather-data/glue/transform-weather-data/main.py"}' \
  --default-arguments file://glue_job_config.json
```

### Step 7: Set Up Apache Airflow

```bash
cd airflow

# Set AIRFLOW_UID environment variable
echo -e "AIRFLOW_UID=$(id -u)" > .env

# Initialize Airflow (first time only)
docker-compose up airflow-init

# Start Airflow services
docker-compose up --build -d
```

**Access Airflow UI:**
- URL: http://localhost:8080
- Username: `airflow`
- Password: `airflow`

### Step 8: Configure Airflow AWS Connection

1. Open Airflow UI → **Admin** → **Connections**
2. Add new connection:
   - **Connection Id**: `aws_conn`
   - **Connection Type**: `Amazon Web Services`
   - **Login**: Your AWS Access Key ID
   - **Password**: Your AWS Secret Access Key
   - **Extra**: `{"region_name": "us-east-1"}` (or your region)

### Step 9: Update Airflow DAG with API Key

Edit `/airflow/dags/pipeline-weather-data.py`:

```python
# Line 284 - Replace with your WeatherAPI key
'api_token': 'YOUR_WEATHERAPI_KEY',
```

### Step 10: Enable and Run the DAG

1. In Airflow UI, find DAG `pipeline-wheater-data` (note: typo in name)
2. Toggle it **ON** (unpause)
3. Click **Trigger DAG** to run manually

---

## Running the Pipeline

### Manual Execution Flow

1. **Airflow DAG triggers** → Creates/updates `dim_locations` table
2. **Generate dates task** → Determines which locations/dates need data
3. **Lambda invocations** → Fetch weather data from API (batched)
4. **Glue job** → Transforms raw JSON into Iceberg tables
5. **Data available** in S3 and Glue Data Catalog

### Pipeline Execution Steps

The DAG performs these tasks in order:

1. `create_or_update_dim_locations_table` - Creates dimension table from S3 JSON
2. `generate_dates_task` - Queries existing data to determine what to fetch
3. `get_api_weather_{actual/forecast}_data_lambda_batch_{N}` - Lambda invocations (parallel batches)
4. `transform_{actual/forecast}_weather_data` - Glue job processes data

### Monitoring

- **Airflow**: Check DAG runs in Airflow UI
- **Lambda**: CloudWatch Logs → `/aws/lambda/get_api_weather_data_lambda`
- **Glue**: AWS Glue Console → Jobs → `transform-weather-data` → Runs
- **S3**: Check buckets for data files

---

## Data Flow

```
WeatherAPI → Lambda → S3 (staging/) → Glue → S3 (warehouse/) → Snowflake
```

**S3 Structure:**
```
s3://weather-datalake-projects/
  ├── pipeline-weather-data/
  │   ├── staging/
  │   │   ├── forecast_data/{location_id}.json
  │   │   ├── actual_data/{location_id}.json
  │   │   └── list_locations_dates_to_process/
  │   ├── warehouse/
  │   │   └── warehouse_weather_data.db/
  │   │       ├── dim_locations/
  │   │       ├── weather_actual_data_timeseries/
  │   │       ├── weather_actual_data_timeseries_agg/
  │   │       └── weather_forecast_data_timeseries/
  │   └── aux_data/
  │       └── dim_locations.json
```

---

## Snowflake Setup (Optional)

If using Snowflake as the final warehouse:

1. Run SQL scripts in `/snowflake/` folder:
   - `creating_resources_in_snowflake.sql` - Creates database, warehouse, catalog integration
   - `creating_tables.sql` - Creates external tables pointing to Iceberg
   - `querying_the_data.sql` - Example queries

2. Update ARNs and IDs in SQL files with your AWS account details

---

## Troubleshooting

### Common Issues

1. **Terraform region mismatch**
   - Check `provider.tf` (us-west-1) vs `variables.tf` (us-east-1)
   - Make them consistent

2. **Lambda timeout**
   - Increase timeout in Lambda configuration (currently 900s)
   - Check CloudWatch logs for errors

3. **Glue job fails**
   - Verify S3 paths in `glue_job_config.json`
   - Check IAM role permissions
   - Review Glue job logs in CloudWatch

4. **Airflow can't connect to AWS**
   - Verify AWS connection credentials
   - Check IAM permissions for Airflow user

5. **API rate limits**
   - WeatherAPI has rate limits
   - Lambda uses semaphore (15 concurrent) to limit requests

### Debugging

- **Lambda**: Check CloudWatch Logs
- **Glue**: Enable Spark UI in job config, check CloudWatch logs
- **Airflow**: Check task logs in Airflow UI
- **S3**: Verify files are created in expected paths

---

## Cost Considerations

- **Lambda**: Pay per invocation (very low cost)
- **Glue**: Pay per DPU-hour (G.1X workers, 3 workers = ~$0.44/hour)
- **S3**: Storage and request costs (minimal for this use case)
- **Airflow**: Free (runs locally)
- **Snowflake**: Pay per compute hour (optional)

---

## Cleanup

To destroy all infrastructure:

```bash
cd terraform
terraform destroy
```

**Note**: This will delete S3 buckets and all data. Make backups if needed!

---

## Additional Resources

- [Medium Article](https://medium.com/@claudiofilho22/end-to-end-data-engineering-project-using-aws-apache-iceberg-snowflake-90b76e7a1082)
- [WeatherAPI Documentation](https://www.weatherapi.com/docs/)
- [Apache Iceberg Documentation](https://iceberg.apache.org/)
- [Airflow Documentation](https://airflow.apache.org/docs/)

---

## Important Notes

1. **API Key**: Replace hardcoded API key in Airflow DAG with environment variable or Airflow Variable
2. **IAM Permissions**: Ensure all roles have necessary permissions
3. **Region Consistency**: Keep AWS regions consistent across all configurations
4. **S3 Bucket Names**: Hardcoded in code - ensure they match Terraform outputs
5. **DAG Name Typo**: DAG ID is `pipeline-wheater-data` (typo: "wheater" instead of "weather")

---

## Next Steps

1. Set up scheduled runs in Airflow (currently `schedule_interval=None`)
2. Add error handling and retries
3. Implement data quality checks
4. Set up monitoring and alerting
5. Connect Tableau to Snowflake for visualization

