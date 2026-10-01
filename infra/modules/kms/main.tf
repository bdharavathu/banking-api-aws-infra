locals {
  root = "arn:aws:iam::${var.account_id}:root"
}

data "aws_iam_policy_document" "data" {
  #checkov:skip=CKV_AWS_109:Key policy; Resource * means this key
  #checkov:skip=CKV_AWS_111:Key policy; Resource * means this key
  #checkov:skip=CKV_AWS_356:Key policy; Resource * means this key
  statement {
    sid       = "AccountAdmin"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [local.root]
    }
  }

  statement {
    sid       = "AlarmsAndEventsPublishToSns"
    actions   = ["kms:GenerateDataKey*", "kms:Decrypt"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com", "events.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

data "aws_iam_policy_document" "logs" {
  #checkov:skip=CKV_AWS_109:Key policy; Resource * means this key
  #checkov:skip=CKV_AWS_111:Key policy; Resource * means this key
  #checkov:skip=CKV_AWS_356:Key policy; Resource * means this key
  statement {
    sid       = "AccountAdmin"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [local.root]
    }
  }

  statement {
    sid = "CloudWatchLogs"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.region}:${var.account_id}:log-group:*"]
    }
  }

  statement {
    sid       = "CloudTrail"
    actions   = ["kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:aws:cloudtrail:*:${var.account_id}:trail/*"]
    }
  }
}

resource "aws_kms_key" "data" {
  description             = "${var.name} application data (RDS, Secrets Manager, ECR, SNS)"
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window_in_days
  policy                  = data.aws_iam_policy_document.data.json
}

resource "aws_kms_alias" "data" {
  name          = "alias/${var.name}-data"
  target_key_id = aws_kms_key.data.key_id
}

resource "aws_kms_key" "logs" {
  description             = "${var.name} logs (CloudWatch Logs, CloudTrail)"
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window_in_days
  policy                  = data.aws_iam_policy_document.logs.json
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.name}-logs"
  target_key_id = aws_kms_key.logs.key_id
}
