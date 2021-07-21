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
  description = "static domain name (eg. example.com)"
  type        = string
}

variable "redirect_domain" {
  description = "redirect target domain (eg. www.example.com)"
  type        = string
}


resource "aws_cloudfront_origin_access_identity" "site_cloudfront_access" {
  comment = "${var.site_name} S3 access identity"
}

resource "aws_s3_bucket" "site_bucket" {
  bucket = "${var.site_name}-site-tf"
  acl    = "private"

  website {
    redirect_all_requests_to = "https://${var.redirect_domain}"
  }

}

resource "aws_acm_certificate" "site_cert" {
  domain_name       = var.site_domain
  validation_method = "DNS"
}

resource "aws_cloudfront_distribution" "site_cloudfront" {
  enabled = true
  origin {
    domain_name = aws_s3_bucket.site_bucket.website_endpoint
    origin_id   = "s3-${aws_s3_bucket.site_bucket.bucket}"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  aliases = [var.site_domain]

  viewer_certificate {
    cloudfront_default_certificate = true
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

output "site_cdn_root_id" {
  description = "CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.site_cloudfront.id
}
output "site_cdn_domain_name" {
  description = "CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.site_cloudfront.domain_name
}
output "site_s3_bucket" {
  description = "Site S3 Bucket id"
  value       = aws_s3_bucket.site_bucket.bucket
}
