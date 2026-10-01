output "build_role_arn" {
  value = aws_iam_role.build.arn
}

output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}
