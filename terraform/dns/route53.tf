terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {}

variable "hosted_zone_id" { type = string }
variable "fqdn"           { type = string }
variable "primary_dns"    { type = string }
variable "secondary_ip"   { type = string }

resource "aws_route53_health_check" "primary" {
  fqdn              = var.fqdn
  port              = 443
  type              = "HTTPS"
  resource_path     = "/healthz"
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_record" "primary" {
  zone_id = var.hosted_zone_id
  name    = var.fqdn
  type    = "A"
  set_identifier = "primary-eks"
  failover_routing_policy { type = "PRIMARY" }
  alias {
    name                   = var.primary_dns
    zone_id                = "Z35SXDOTRQ7X7K" # ALB zone ID (adjust if NLB)
    evaluate_target_health = true
  }
  health_check_id = aws_route53_health_check.primary.id
}

resource "aws_route53_record" "secondary" {
  zone_id = var.hosted_zone_id
  name    = var.fqdn
  type    = "A"
  set_identifier = "secondary-gke"
  failover_routing_policy { type = "SECONDARY" }
  ttl     = 30
  records = [var.secondary_ip]
}
