terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region"            { type = string }
variable "bucket"            { type = string }
variable "account_id"        { type = string }
variable "oidc_provider_arn" { type = string }
variable "oidc_provider_url" { type = string }

resource "aws_s3_bucket" "velero" {
  bucket = var.bucket
}

resource "aws_s3_bucket_versioning" "v" {
  bucket = aws_s3_bucket.velero.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.velero.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "velero_s3" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListBucket",
      "s3:ListMultipartUploadParts",
      "s3:PutObjectTagging"
    ]
    resources = [
      "arn:aws:s3:::${var.bucket}",
      "arn:aws:s3:::${var.bucket}/*"
    ]
  }
}

resource "aws_iam_policy" "velero_s3" {
  name   = "VeleroS3-${var.bucket}"
  policy = data.aws_iam_policy_document.velero_s3.json
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:velero:velero"]
    }
  }
}

resource "aws_iam_role" "velero" {
  name               = "srespace-${var.bucket}-irsa"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.velero.name
  policy_arn = aws_iam_policy.velero_s3.arn
}

output "bucket"        { value = aws_s3_bucket.velero.bucket }
output "irsa_role_arn" { value = aws_iam_role.velero.arn }
