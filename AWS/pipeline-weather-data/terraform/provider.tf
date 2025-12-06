provider "aws" {
  region  = "us-west-1" # Change this to your desired region
#   profile = "dev"
}

data "aws_caller_identity" "current" {}

