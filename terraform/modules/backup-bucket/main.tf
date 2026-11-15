# A private bucket for backups, on any server that speaks the S3 protocol.
# Backups are the point of it, so OpenTofu never empties or removes one.

variable "name" {
  description = "Name of the bucket. At Hetzner, names are shared by all customers, so pick one nobody else has."
  type        = string
}

resource "minio_s3_bucket" "this" {
  bucket        = var.name
  acl           = "private"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

output "name" {
  description = "Name of the bucket."
  value       = minio_s3_bucket.this.bucket
}
