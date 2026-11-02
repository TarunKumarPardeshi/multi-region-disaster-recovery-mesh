output "arc_cluster_endpoints" {
  description = "Regional endpoints for Route 53 ARC cluster"
  value       = aws_route53recoverycontrolconfig_cluster.dr_cluster.cluster_endpoints
}

output "primary_routing_control_arn" {
  description = "Routing control ARN for primary region"
  value       = aws_route53recoverycontrolconfig_routing_control.primary_routing_control.arn
}

output "secondary_routing_control_arn" {
  description = "Routing control ARN for secondary region"
  value       = aws_route53recoverycontrolconfig_routing_control.secondary_routing_control.arn
}

output "dynamodb_global_table_arn" {
  description = "DynamoDB Global Table ARN replicated across primary and secondary regions"
  value       = aws_dynamodb_table.global_orders.arn
}
