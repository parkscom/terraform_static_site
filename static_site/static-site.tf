terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region for static site publishing"
  type        = string
}

variable "site_name" {
  description = "Static site name, using on S3 bucketname and other resources basename"
  type        = string
}

variable "site_domain" {
  description = "static domain name (eg. www.example.com)"
  type        = string
}

resource "aws_cloudfront_origin_access_identity" "site_cloudfront_access" {
  comment = "${var.site_name} S3 access identity"
}

resource "aws_s3_bucket" "site_bucket" {
  bucket = "${var.site_name}-site-tf"
  acl    = "private"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.site_cloudfront_access.id}"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${var.site_name}-site-tf/*"
        }
    ]
}
EOF

  website {
    index_document = "index.html"
  }
}

resource "aws_acm_certificate" "site_cert" {
  domain_name       = var.site_domain
  validation_method = "DNS"
}

resource "aws_cloudfront_distribution" "site_cloudfront" {
  enabled = true
  origin {
    domain_name = aws_s3_bucket.site_bucket.bucket_regional_domain_name
    origin_id   = "s3-${aws_s3_bucket.site_bucket.bucket}"
    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/${aws_cloudfront_origin_access_identity.site_cloudfront_access.id}"
    }
  }
  default_root_object = "index.html"

  aliases = [var.site_domain]

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = aws_acm_certificate.site_cert.arn
    ssl_support_method             = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-${aws_s3_bucket.site_bucket.bucket}"

    viewer_protocol_policy = "allow-all"

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }
  }
}