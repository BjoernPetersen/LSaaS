resource "aws_s3_bucket" "bucket" {
  bucket = var.s3_bucket_name
  acl    = "private"

  lifecycle_rule {
    id                                     = "DeleteOldObjects"
    enabled                                = true
    abort_incomplete_multipart_upload_days = 7
    expiration {
      days = 1
    }
    noncurrent_version_expiration {
      days = 1
    }
  }
}

resource "aws_s3_bucket_public_access_block" "private_bucket" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
