output "state_bucket" {
  value = aws_s3_bucket.state.id
}

output "state_kms_key_arn" {
  value = aws_kms_key.state.arn
}

output "github_oidc_provider_arn" {
  value = local.oidc_provider
}

output "terraform_plan_role_arn" {
  value = aws_iam_role.plan.arn
}

output "terraform_apply_role_arn" {
  value = aws_iam_role.apply.arn
}

output "backend_config" {
  value = <<-EOT
    bucket       = "${aws_s3_bucket.state.id}"
    region       = "${var.region}"
    kms_key_id   = "${aws_kms_key.state.arn}"
  EOT
}
