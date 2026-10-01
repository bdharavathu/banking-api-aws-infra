locals {
  namespace = "BankingApi/${var.environment}"

  alb_dims = { LoadBalancer = var.alb_arn_suffix }
  tg_dims  = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix }
  ecs_dims = { ClusterName = var.cluster_name, ServiceName = var.service_name }
  rds_dims = { DBInstanceIdentifier = var.db_identifier }
  waf_dims = { WebACL = coalesce(var.web_acl_name, "none"), Region = var.region, Rule = "ALL" }

  log_metrics = {
    Deposits            = "{ $.event = \"deposit\" }"
    Withdrawals         = "{ $.event = \"withdrawal\" }"
    WithdrawalsRejected = "{ $.event = \"withdrawal_rejected\" }"
    AuthFailures        = "{ $.event = \"auth_failed\" }"
    UnhandledErrors     = "{ $.event = \"unhandled_error\" }"
    Http5xx             = "{ $.event = \"http_request\" && $.status >= 500 }"
  }

  alarms = merge(
    {
      alb-5xx = {
        description = "ALB returned 5xx (no healthy target, timeouts)"
        namespace   = "AWS/ApplicationELB"
        metric      = "HTTPCode_ELB_5XX_Count"
        dimensions  = local.alb_dims
        statistic   = "Sum"
        period      = 300
        periods     = 1
        threshold   = 5
        operator    = "GreaterThanOrEqualToThreshold"
      }
      target-5xx = {
        description = "Application returned 5xx"
        namespace   = "AWS/ApplicationELB"
        metric      = "HTTPCode_Target_5XX_Count"
        dimensions  = local.tg_dims
        statistic   = "Sum"
        period      = 300
        periods     = 1
        threshold   = 5
        operator    = "GreaterThanOrEqualToThreshold"
      }
      unhealthy-targets = {
        description = "At least one ECS task is failing ALB health checks"
        namespace   = "AWS/ApplicationELB"
        metric      = "UnHealthyHostCount"
        dimensions  = local.tg_dims
        statistic   = "Maximum"
        period      = 60
        periods     = 3
        threshold   = 0
        operator    = "GreaterThanThreshold"
      }
      latency-p95 = {
        description = "p95 response time above 1s"
        namespace   = "AWS/ApplicationELB"
        metric      = "TargetResponseTime"
        dimensions  = local.tg_dims
        statistic   = null
        extended    = "p95"
        period      = 300
        periods     = 2
        threshold   = 1
        operator    = "GreaterThanThreshold"
      }
      ecs-cpu-high = {
        description = "ECS service CPU above 80%"
        namespace   = "AWS/ECS"
        metric      = "CPUUtilization"
        dimensions  = local.ecs_dims
        statistic   = "Average"
        period      = 300
        periods     = 2
        threshold   = 80
        operator    = "GreaterThanThreshold"
      }
      ecs-memory-high = {
        description = "ECS service memory above 80%"
        namespace   = "AWS/ECS"
        metric      = "MemoryUtilization"
        dimensions  = local.ecs_dims
        statistic   = "Average"
        period      = 300
        periods     = 2
        threshold   = 80
        operator    = "GreaterThanThreshold"
      }
      rds-cpu-high = {
        description = "RDS CPU above 80%"
        namespace   = "AWS/RDS"
        metric      = "CPUUtilization"
        dimensions  = local.rds_dims
        statistic   = "Average"
        period      = 300
        periods     = 2
        threshold   = 80
        operator    = "GreaterThanThreshold"
      }
      rds-storage-low = {
        description = "RDS free storage below 2 GiB"
        namespace   = "AWS/RDS"
        metric      = "FreeStorageSpace"
        dimensions  = local.rds_dims
        statistic   = "Minimum"
        period      = 300
        periods     = 1
        threshold   = 2147483648
        operator    = "LessThanThreshold"
      }
      rds-connections-high = {
        description = "RDS connections close to the instance limit"
        namespace   = "AWS/RDS"
        metric      = "DatabaseConnections"
        dimensions  = local.rds_dims
        statistic   = "Maximum"
        period      = 300
        periods     = 2
        threshold   = 60
        operator    = "GreaterThanThreshold"
      }
      auth-failures = {
        description = "Burst of failed API key checks (possible credential stuffing)"
        namespace   = local.namespace
        metric      = "AuthFailures"
        dimensions  = {}
        statistic   = "Sum"
        period      = 300
        periods     = 1
        threshold   = 20
        operator    = "GreaterThanOrEqualToThreshold"
      }
      unhandled-errors = {
        description = "Application raised unhandled exceptions"
        namespace   = local.namespace
        metric      = "UnhandledErrors"
        dimensions  = {}
        statistic   = "Sum"
        period      = 300
        periods     = 1
        threshold   = 1
        operator    = "GreaterThanOrEqualToThreshold"
      }
    },
    var.web_acl_name == null ? {} : {
      waf-blocked-spike = {
        description = "WAF is blocking an unusual number of requests"
        namespace   = "AWS/WAFV2"
        metric      = "BlockedRequests"
        dimensions  = local.waf_dims
        statistic   = "Sum"
        period      = 300
        periods     = 1
        threshold   = 100
        operator    = "GreaterThanOrEqualToThreshold"
      }
    },
  )
}

resource "aws_sns_topic" "alerts" {
  name              = "${var.name}-alerts"
  kms_master_key_id = var.kms_key_arn
}

data "aws_iam_policy_document" "alerts" {
  statement {
    sid       = "CloudWatchAndEventBridgePublish"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
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

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts.json
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_log_metric_filter" "app" {
  for_each       = local.log_metrics
  name           = "${var.name}-${each.key}"
  log_group_name = var.app_log_group_name
  pattern        = each.value

  metric_transformation {
    name          = each.key
    namespace     = local.namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = local.alarms

  alarm_name          = "${var.name}-${each.key}"
  alarm_description   = each.value.description
  namespace           = each.value.namespace
  metric_name         = each.value.metric
  dimensions          = each.value.dimensions
  statistic           = each.value.statistic
  extended_statistic  = lookup(each.value, "extended", null)
  period              = each.value.period
  evaluation_periods  = each.value.periods
  threshold           = each.value.threshold
  comparison_operator = each.value.operator
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  depends_on = [aws_cloudwatch_log_metric_filter.app]
}

resource "aws_cloudwatch_event_rule" "guardduty" {
  name        = "${var.name}-guardduty-findings"
  description = "GuardDuty findings with severity >= 4"
  event_pattern = jsonencode({
    source        = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
    detail        = { severity = [{ numeric = [">=", 4] }] }
  })
}

resource "aws_cloudwatch_event_target" "guardduty" {
  rule      = aws_cloudwatch_event_rule.guardduty.name
  target_id = "sns"
  arn       = aws_sns_topic.alerts.arn
}

resource "aws_cloudwatch_query_definition" "errors" {
  name            = "${var.name}/errors-by-route"
  log_group_names = [var.app_log_group_name]
  query_string    = <<-EOT
    fields @timestamp, route, status, request_id
    | filter event = "http_request" and status >= 500
    | stats count(*) as errors by route, status
    | sort errors desc
  EOT
}

resource "aws_cloudwatch_query_definition" "slow_requests" {
  name            = "${var.name}/slowest-requests"
  log_group_names = [var.app_log_group_name]
  query_string    = <<-EOT
    fields @timestamp, method, route, status, duration_ms, request_id
    | filter event = "http_request"
    | sort duration_ms desc
    | limit 50
  EOT
}

resource "aws_cloudwatch_query_definition" "auth_failures" {
  name            = "${var.name}/auth-failures-by-ip"
  log_group_names = [var.app_log_group_name]
  query_string    = <<-EOT
    fields @timestamp, client_ip, path, status
    | filter event = "http_request" and status = 401
    | stats count(*) as failures by client_ip
    | sort failures desc
  EOT
}

resource "aws_cloudwatch_query_definition" "trace_request" {
  name            = "${var.name}/trace-request-id"
  log_group_names = [var.app_log_group_name]
  query_string    = <<-EOT
    fields @timestamp, level, logger, message, event, status
    | filter request_id = "REPLACE_ME"
    | sort @timestamp asc
  EOT
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = var.name
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 8, height = 6
        properties = {
          title  = "Requests and errors"
          region = var.region
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."],
            [".", "HTTPCode_ELB_5XX_Count", ".", "."],
          ]
        }
      },
      {
        type = "metric", x = 8, y = 0, width = 8, height = 6
        properties = {
          title  = "Latency (s)"
          region = var.region
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p50" }],
            ["...", { stat = "p95" }],
            ["...", { stat = "p99" }],
          ]
        }
      },
      {
        type = "metric", x = 16, y = 0, width = 8, height = 6
        properties = {
          title  = "Target health"
          region = var.region
          stat   = "Minimum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Maximum" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 8, height = 6
        properties = {
          title  = "Business activity"
          region = var.region
          stat   = "Sum"
          period = 300
          metrics = [
            [local.namespace, "Deposits"],
            [".", "Withdrawals"],
            [".", "WithdrawalsRejected"],
          ]
        }
      },
      {
        type = "metric", x = 8, y = 6, width = 8, height = 6
        properties = {
          title  = "Security signals"
          region = var.region
          stat   = "Sum"
          period = 300
          metrics = concat(
            [[local.namespace, "AuthFailures"], [".", "UnhandledErrors"]],
            var.web_acl_name == null ? [] : [["AWS/WAFV2", "BlockedRequests", "WebACL", var.web_acl_name, "Region", var.region, "Rule", "ALL"]],
          )
        }
      },
      {
        type = "metric", x = 16, y = 6, width = 8, height = 6
        properties = {
          title  = "ECS service"
          region = var.region
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", var.service_name],
            [".", "MemoryUtilization", ".", ".", ".", "."],
            ["ECS/ContainerInsights", "RunningTaskCount", ".", ".", ".", ".", { yAxis = "right" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6
        properties = {
          title  = "RDS"
          region = var.region
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_identifier],
            [".", "DatabaseConnections", ".", ".", { yAxis = "right" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 12, width = 12, height = 6
        properties = {
          title  = "RDS latency and storage"
          region = var.region
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", var.db_identifier],
            [".", "WriteLatency", ".", "."],
            [".", "FreeStorageSpace", ".", ".", { yAxis = "right" }],
          ]
        }
      },
      {
        type = "log", x = 0, y = 18, width = 24, height = 6
        properties = {
          title  = "Recent errors"
          region = var.region
          query  = "SOURCE '${var.app_log_group_name}' | fields @timestamp, level, message, route, status, request_id | filter level = \"ERROR\" or status >= 500 | sort @timestamp desc | limit 50"
          view   = "table"
        }
      },
    ]
  })
}
