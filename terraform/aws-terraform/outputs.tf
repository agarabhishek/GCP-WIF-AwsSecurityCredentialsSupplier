output "ecs_cluster_name" {
  value = aws_ecs_cluster.gcp_wif_cluster.name
}

output "ecs_task_definition_arn" {
  value = aws_ecs_task_definition.gcp_wif_task.arn
}

output "ecs_subnet_id" {
  value = aws_subnet.ecs.id
}

output "ecs_security_group_id" {
  value = aws_security_group.sg.id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.gcp_wif_bucket.bucket
}