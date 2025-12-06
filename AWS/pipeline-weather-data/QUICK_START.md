# Quick Start Checklist

Use this checklist to quickly set up and run the Weather Data Pipeline.

## Pre-Setup Checklist

- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Terraform installed (v1.0+)
- [ ] Docker and Docker Compose installed
- [ ] WeatherAPI account and API key obtained
- [ ] GitHub repository (if using CodeBuild CI/CD)

## Configuration Checklist

- [ ] Update `terraform/variables.tf`:
  - [ ] AWS Account ID
  - [ ] AWS Region (match with `provider.tf`)
  - [ ] GitHub owner/repo (if using CodeBuild)
  - [ ] Snowflake ARNs (if using Snowflake)

- [ ] Update `lambda/buildspec.yml`:
  - [ ] Lambda execution role ARN

- [ ] Update `glue/transform-weather-data/glue_job_config.json`:
  - [ ] Glue role ARN

- [ ] Update `airflow/dags/pipeline-weather-data.py`:
  - [ ] WeatherAPI key (line 284)

## Deployment Checklist

- [ ] **Deploy Infrastructure**
  ```bash
  cd terraform
  terraform init
  terraform plan
  terraform apply
  ```

- [ ] **Deploy Lambda** (choose one)
  - [ ] Option A: Push to GitHub (CodeBuild auto-deploys)
  - [ ] Option B: Manual deployment (see SETUP_GUIDE.md)

- [ ] **Deploy Glue Job** (choose one)
  - [ ] Option A: Push to GitHub (CodeBuild auto-deploys)
  - [ ] Option B: Manual deployment (see SETUP_GUIDE.md)

- [ ] **Start Airflow**
  ```bash
  cd airflow
  echo -e "AIRFLOW_UID=$(id -u)" > .env
  docker-compose up airflow-init
  docker-compose up --build -d
  ```

- [ ] **Configure Airflow AWS Connection**
  - [ ] Connection ID: `aws_conn`
  - [ ] Type: Amazon Web Services
  - [ ] AWS Access Key ID
  - [ ] AWS Secret Access Key
  - [ ] Region in Extra JSON

## Run Checklist

- [ ] Access Airflow UI: http://localhost:8080
- [ ] Login: `airflow` / `airflow`
- [ ] Find DAG: `pipeline-wheater-data`
- [ ] Toggle DAG ON (unpause)
- [ ] Trigger DAG manually
- [ ] Monitor execution in Airflow UI

## Verification Checklist

- [ ] Check Lambda logs in CloudWatch
- [ ] Check Glue job runs in AWS Console
- [ ] Verify S3 buckets have data:
  - [ ] `s3://weather-datalake-projects/pipeline-weather-data/staging/`
  - [ ] `s3://weather-datalake-projects/pipeline-weather-data/warehouse/`
- [ ] Query Glue Data Catalog tables (via Athena or Glue Console)
- [ ] (Optional) Connect Snowflake and verify data

## Common Issues Quick Fix

| Issue | Quick Fix |
|-------|-----------|
| Region mismatch | Check `provider.tf` vs `variables.tf` |
| Lambda timeout | Increase timeout to 900s |
| Airflow can't connect AWS | Verify AWS connection credentials |
| Glue job fails | Check S3 paths and IAM permissions |
| API rate limits | Lambda already limits to 15 concurrent |

## Quick Commands Reference

```bash
# Terraform
cd terraform && terraform init && terraform plan && terraform apply

# Airflow
cd airflow && docker-compose up -d
cd airflow && docker-compose down

# Check Lambda logs
aws logs tail /aws/lambda/get_api_weather_data_lambda --follow

# List S3 files
aws s3 ls s3://weather-datalake-projects/pipeline-weather-data/staging/actual_data/

# Check Glue job status
aws glue get-job --job-name transform-weather-data
```

## Estimated Time

- Initial setup: 30-60 minutes
- First pipeline run: 10-30 minutes (depending on data volume)
- Subsequent runs: 5-15 minutes

---

**Need detailed instructions?** See [SETUP_GUIDE.md](./SETUP_GUIDE.md)

