# How to Get Snowflake Integration Values

This guide explains how to obtain the three Snowflake values needed for the Terraform configuration:

1. `aws_iam_user_arn_by_snowflake`
2. `glue_aws_external_id_by_snowflake`
3. `storage_aws_external_id_by_snowflake`

---

## Prerequisites

- Snowflake account with ACCOUNTADMIN role (or sufficient privileges)
- AWS account where you'll deploy the infrastructure
- Access to Snowflake web interface or SnowSQL

---

## Step 1: Create IAM User in AWS for Snowflake

Snowflake needs an IAM user to assume roles in AWS. This user ARN is what you'll use for `aws_iam_user_arn_by_snowflake`.

### Option A: Use Existing IAM User (if you have one)

If you already have a Snowflake IAM user, get its ARN:

```bash
aws iam get-user --user-name YOUR_SNOWFLAKE_USERNAME
```

The ARN will look like: `arn:aws:iam::ACCOUNT_ID:user/USERNAME`

### Option B: Create New IAM User

1. **Go to AWS IAM Console** → Users → Create User

2. **User name**: `snowflake-integration-user` (or any name you prefer)

3. **No permissions needed** (Snowflake will assume roles, not use direct permissions)

4. **After creation, note the ARN**:
   - Format: `arn:aws:iam::YOUR_ACCOUNT_ID:user/snowflake-integration-user`
   - This is your `aws_iam_user_arn_by_snowflake` value

5. **Create Access Keys** (optional, for testing):
   - Go to Security credentials tab
   - Create access key
   - Save the Access Key ID and Secret Access Key (you'll need these for Snowflake)

---

## Step 2: Get External IDs from Snowflake

External IDs are security tokens that Snowflake generates when you create integrations. You need to create two integrations in Snowflake:

### A. Get Glue Catalog Integration External ID

1. **Log into Snowflake** as ACCOUNTADMIN

2. **Create a Catalog Integration** (this will generate the external ID):

```sql
CREATE OR REPLACE CATALOG INTEGRATION glueCatalog_WarehouseWeatherData
  CATALOG_SOURCE = GLUE
  CATALOG_NAMESPACE = 'warehouse_weather_data'
  TABLE_FORMAT = ICEBERG
  GLUE_AWS_ROLE_ARN = 'arn:aws:iam::YOUR_ACCOUNT_ID:role/snowflake_service_role'
  GLUE_CATALOG_ID = 'YOUR_GLUE_CATALOG_ID'  -- Your AWS Account ID
  GLUE_REGION = 'us-west-1'  -- Your AWS region
  ENABLED = TRUE
  REFRESH_INTERVAL_SECONDS = 600;
```

**Note**: The role `snowflake_service_role` doesn't exist yet - that's okay, we'll create it with Terraform later.

3. **Get the External ID**:

```sql
DESC CATALOG INTEGRATION glueCatalog_WarehouseWeatherData;
```

Look for the `GLUE_AWS_EXTERNAL_ID` field in the output. This is your `glue_aws_external_id_by_snowflake` value.

**Alternative method** (if DESC doesn't show it):

```sql
SHOW CATALOG INTEGRATIONS;
SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
```

Or check the Snowflake web UI:
- Go to **Admin** → **Integrations**
- Click on your catalog integration
- Look for **External ID** or **AWS External ID**

### B. Get Storage (S3) External Volume External ID

1. **Create an External Volume** in Snowflake:

```sql
CREATE OR REPLACE EXTERNAL VOLUME warehouse_weather_data_vol
   STORAGE_LOCATIONS =
        (
            (
               NAME = 's3_warehouse_weather_data.db'
               STORAGE_PROVIDER= 'S3'
               STORAGE_BASE_URL = 's3://weather-datalake-projects/pipeline-weather-data/warehouse/warehouse_weather_data.db/'
               STORAGE_AWS_ROLE_ARN='arn:aws:iam::YOUR_ACCOUNT_ID:role/snowflake_service_role'
            )
        )
    ALLOW_WRITES=FALSE;
```

**Note**: Again, the role doesn't exist yet - that's fine.

2. **Get the External ID**:

```sql
DESC EXTERNAL VOLUME warehouse_weather_data_vol;
```

Look for the `STORAGE_AWS_EXTERNAL_ID` field. This is your `storage_aws_external_id_by_snowflake` value.

**Alternative method**:

```sql
SHOW EXTERNAL VOLUMES;
SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
```

Or in Snowflake web UI:
- Go to **Data** → **Databases** → **External Volumes**
- Click on your external volume
- Look for **External ID** or **AWS External ID**

---

## Step 3: Get AWS Account ID and Glue Catalog ID

You'll also need these for the Snowflake SQL scripts:

1. **AWS Account ID**:
   ```bash
   aws sts get-caller-identity --query Account --output text
   ```
   
   Or check in AWS Console → Support Center (top right)

2. **Glue Catalog ID**: This is the same as your AWS Account ID for most cases.

---

## Summary: What You Should Have

After completing the steps above, you should have:

| Variable | Where to Find | Example Format |
|----------|---------------|----------------|
| `aws_iam_user_arn_by_snowflake` | AWS IAM User ARN | `arn:aws:iam::123456789012:user/snowflake-integration-user` |
| `glue_aws_external_id_by_snowflake` | From `DESC CATALOG INTEGRATION` | `SNOWFLAKE_GLUE_EXT_ID_1234567890ABCDEF` |
| `storage_aws_external_id_by_snowflake` | From `DESC EXTERNAL VOLUME` | `SNOWFLAKE_STORAGE_EXT_ID_1234567890ABCDEF` |

---

## Important Notes

### Order of Operations

**Option 1: Create Snowflake integrations first (recommended)**
1. Create IAM user in AWS
2. Create Snowflake integrations (they'll generate external IDs)
3. Get external IDs from Snowflake
4. Update Terraform variables with all three values
5. Run `terraform apply` (creates the IAM role that Snowflake will use)

**Option 2: Create AWS resources first**
1. Create IAM user in AWS
2. Run Terraform (creates IAM role with placeholder external IDs)
3. Create Snowflake integrations (use the role ARN from Terraform)
4. Get external IDs from Snowflake
5. Update Terraform variables with correct external IDs
6. Run `terraform apply` again to update the role

### Security Best Practices

- **External IDs are secrets** - treat them like passwords
- Store them securely (use Terraform variables file, AWS Secrets Manager, or environment variables)
- Don't commit them to version control
- Rotate them periodically if needed

### Troubleshooting

**Problem**: "External ID doesn't match"
- **Solution**: Make sure you're using the exact external ID from Snowflake (case-sensitive, no extra spaces)

**Problem**: "IAM user not found"
- **Solution**: Verify the IAM user ARN is correct and the user exists in the same AWS account

**Problem**: "Role cannot be assumed"
- **Solution**: 
  1. Check the IAM role trust policy includes the Snowflake IAM user ARN
  2. Verify external IDs match exactly
  3. Ensure the role exists before creating Snowflake integrations

---

## Quick Reference Commands

```sql
-- Get Glue Catalog Integration External ID
DESC CATALOG INTEGRATION glueCatalog_WarehouseWeatherData;

-- Get External Volume External ID  
DESC EXTERNAL VOLUME warehouse_weather_data_vol;

-- List all integrations
SHOW CATALOG INTEGRATIONS;
SHOW EXTERNAL VOLUMES;
```

```bash
# Get AWS Account ID
aws sts get-caller-identity --query Account --output text

# Get IAM User ARN
aws iam get-user --user-name snowflake-integration-user --query 'User.Arn' --output text
```

---

## Next Steps

Once you have all three values:

1. Update `terraform/variables.tf`:
   ```hcl
   variable "aws_iam_user_arn_by_snowflake" {
     default = "arn:aws:iam::123456789012:user/snowflake-integration-user"
   }
   
   variable "glue_aws_external_id_by_snowflake" {
     default = "SNOWFLAKE_GLUE_EXT_ID_1234567890ABCDEF"
   }
   
   variable "storage_aws_external_id_by_snowflake" {
     default = "SNOWFLAKE_STORAGE_EXT_ID_1234567890ABCDEF"
   }
   ```

2. Update `snowflake/creating_resources_in_snowflake.sql` with your AWS Account ID

3. Run `terraform apply` to create the IAM role

4. The Snowflake integrations should now be able to assume the role!

---

**Need help?** Check the [Snowflake Documentation on External Integrations](https://docs.snowflake.com/en/user-guide/external-integrations.html)

