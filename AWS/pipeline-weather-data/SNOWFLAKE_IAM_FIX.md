# Snowflake IAM Role Error - Fixed

## Problem

The Terraform apply was failing with:
```
Error: Invalid principal in policy: "AWS":"arn:aws:iam::779854054450:user/BUQZDTX-QCB24090"
```

**Root Cause**: The IAM user `BUQZDTX-QCB24090` specified in `aws_iam_user_arn_by_snowflake` does not exist in your AWS account. AWS validates that principals in IAM trust policies exist, so it rejects the policy.

## Solution

Made the Snowflake IAM role **optional** by adding a new variable `enable_snowflake_integration` (default: `false`).

### Changes Made

1. ✅ Added `enable_snowflake_integration` variable (default: `false`)
2. ✅ Made `aws_iam_role.snowflake_service_role` conditional using `count`
3. ✅ Made `aws_iam_policy.snowflake_service_role_policy` conditional
4. ✅ Made `aws_iam_role_policy_attachment.snowflake_role_policy_attachment` conditional
5. ✅ Fixed Principal format (removed array, using string directly)

## How to Use

### Option 1: Skip Snowflake (Recommended for now)

By default, Snowflake integration is **disabled**. Just run:

```bash
cd terraform
terraform apply
```

The Snowflake role won't be created, and Terraform will succeed.

### Option 2: Enable Snowflake Integration

If you want to use Snowflake, you need to:

1. **Create the IAM user first**:
   ```bash
   aws iam create-user --user-name BUQZDTX-QCB24090
   ```
   
   Or use a different user name and update the variable:
   ```hcl
   variable "aws_iam_user_arn_by_snowflake" {
     default = "arn:aws:iam::779854054450:user/YOUR_USERNAME"
   }
   ```

2. **Enable Snowflake integration** in `variables.tf`:
   ```hcl
   variable "enable_snowflake_integration" {
     default = true  # Change from false to true
   }
   ```

3. **Run Terraform**:
   ```bash
   terraform apply
   ```

## Verify IAM User Exists

Check if your IAM user exists:
```bash
aws iam get-user --user-name BUQZDTX-QCB24090
```

If it doesn't exist, you'll see:
```
An error occurred (NoSuchEntity) when calling the GetUser operation
```

## Next Steps

1. **For now**: Run `terraform apply` - it will skip Snowflake resources
2. **Later**: If you need Snowflake:
   - Create the IAM user (or use existing one)
   - Update `enable_snowflake_integration = true`
   - Run `terraform apply` again

## Note

The Snowflake integration is **optional** for this pipeline. The pipeline works perfectly fine without Snowflake - data will be stored in S3 and accessible via Glue Data Catalog/Athena. Snowflake is only needed if you want to use it as the final data warehouse for BI tools like Tableau.

