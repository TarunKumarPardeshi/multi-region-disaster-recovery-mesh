terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

# 1. Primary Region Provider (Canada Central)
provider "aws" {
  alias  = "primary"
  region = var.primary_region
}

# 2. Secondary Region Provider (US East N. Virginia)
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

# Route 53 ARC Cluster (Resilient cross-region control plane)
resource "aws_route53recoverycontrolconfig_cluster" "dr_cluster" {
  provider = aws.primary
  name     = "${var.project_name}-arc-cluster"

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ARC Control Panel
resource "aws_route53recoverycontrolconfig_control_panel" "dr_control_panel" {
  provider    = aws.primary
  name        = "${var.project_name}-control-panel"
  cluster_arn = aws_route53recoverycontrolconfig_cluster.dr_cluster.arn
}

# Primary Region Routing Control
resource "aws_route53recoverycontrolconfig_routing_control" "primary_routing_control" {
  provider          = aws.primary
  name              = "${var.project_name}-${var.primary_region}-routing-control"
  cluster_arn       = aws_route53recoverycontrolconfig_cluster.dr_cluster.arn
  control_panel_arn = aws_route53recoverycontrolconfig_control_panel.dr_control_panel.arn
}

# Secondary Region Routing Control
resource "aws_route53recoverycontrolconfig_routing_control" "secondary_routing_control" {
  provider          = aws.primary
  name              = "${var.project_name}-${var.secondary_region}-routing-control"
  cluster_arn       = aws_route53recoverycontrolconfig_cluster.dr_cluster.arn
  control_panel_arn = aws_route53recoverycontrolconfig_control_panel.dr_control_panel.arn
}

# Route 53 Health Checks driven by ARC Routing Controls
resource "aws_route53_health_check" "primary_arc_health_check" {
  provider          = aws.primary
  type              = "RECOVERY_CONTROL"
  routing_control_arn = aws_route53recoverycontrolconfig_routing_control.primary_routing_control.arn

  tags = {
    Name = "${var.project_name}-${var.primary_region}-arc-hc"
  }
}

resource "aws_route53_health_check" "secondary_arc_health_check" {
  provider          = aws.primary
  type              = "RECOVERY_CONTROL"
  routing_control_arn = aws_route53recoverycontrolconfig_routing_control.secondary_routing_control.arn

  tags = {
    Name = "${var.project_name}-${var.secondary_region}-arc-hc"
  }
}

# DynamoDB Global Table (Active-Active Bi-Directional Replication)
resource "aws_dynamodb_table" "global_orders" {
  provider     = aws.primary
  name         = "${var.project_name}-GlobalOrders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "order_id"
    type = "S"
  }

  replica {
    region_name = var.secondary_region
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Environment = var.environment
    Architecture = "Active-Active-Global"
  }
}
