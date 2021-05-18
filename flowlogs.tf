# https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/flow-logs.html

data aws_iam_policy_document trust {
  statement {
    sid     = "VPCFlowLogsAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data aws_iam_policy_document flowlog {
  statement {
    sid = "vpcflowlogpolicydoc"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutSubscriptionFilter",
      "logs:CreateLogDelivery",
      "logs:DeleteLogDelivery"
    ]

    resources = ["*"]
  }
}

resource aws_iam_policy flowlog {
  name        = join("-", ["vpc-flowlog-policy", local.vpc_id])
  path        = "/"
  description = "VPC Flow Logs Policy"
  policy      = data.aws_iam_policy_document.flowlog.json
  tags        = var.tags
}

resource aws_iam_role flowlog {
  name               = join("-", ["vpc-flowlog-role", local.vpc_id])
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

resource aws_iam_role_policy_attachment flowlog {
  role       = aws_iam_role.flowlog.name
  policy_arn = aws_iam_policy.flowlog.arn
}

#####################################
# KMS Key for VPC Flowlogs Log Group
#####################################
resource "aws_kms_key" "flowlogs" {
  count                    = var.encrypt_flow_logs ? 1 : 0
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  deletion_window_in_days  = 7
  description              = "encryption for vpc flowlogs"
  enable_key_rotation      = true
  is_enabled               = true
  key_usage                = "ENCRYPT_DECRYPT"
  policy                   = data.aws_iam_policy_document.flowlogs.json
  tags                     = var.tags
}

resource "aws_kms_alias" "flowlogs" {
  count         = var.encrypt_flow_logs ? 1 : 0
  target_key_id = aws_kms_key.flowlogs[0].id
  name          = join("-", ["alias/", var.name, "flowlogs"])
}

data "aws_iam_policy_document" "flowlogs" {
  statement {
    sid = "Enable IAM User Permissions"
    actions = [
      "kms:*"
    ]
    effect    = "Allow"
    resources = ["*"]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }
  }
  statement {
    sid = "Allow cloudwatch use of the CMK"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    effect    = "Allow"
    resources = ["*"]
    principals {
      type = "Service"
      identifiers = [
        "logs.${data.aws_region.current.name}.amazonaws.com"
      ]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      ]
    }
  }
}

###########
# FlowLogs
###########
resource "aws_cloudwatch_log_group" "flowlogs" {
  name              = join("-", [var.name, "flowlogs"])
  kms_key_id        = var.encrypt_flow_logs == true ? aws_kms_key.flowlogs[0].arn : null
  retention_in_days = var.log_group_retention_in_days
  tags              = var.tags
}

resource "aws_flow_log" "default" {
  log_destination = aws_cloudwatch_log_group.flowlogs.arn
  iam_role_arn    = aws_iam_role.flowlog.arn
  vpc_id          = local.vpc_id
  traffic_type    = "ALL"
  log_format      = var.flowlog_format
  tags            = var.tags
}

resource "aws_cloudwatch_log_subscription_filter" "flowlog_subscription_filter" {
  count           = var.vpc_flowlogs_cloudwatch_destination_arn != null ? 1 : 0
  name            = join("-", ["flowlog-subscription-filter", local.vpc_id])
  log_group_name  = aws_cloudwatch_log_group.flowlogs.name
  filter_pattern  = ""
  destination_arn = var.vpc_flowlogs_cloudwatch_destination_arn
}
