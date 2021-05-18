terraform {
  required_version = ">= 0.10.3" # introduction of Local Values configuration language feature
}

locals {
  nat_gateway_count = var.single_nat_gateway ? 1 : (var.one_nat_gateway_per_az ? length(var.azs) : length(var.private_subnets))
  vpc_id            = aws_vpc.this.id
  # vpce_subnets      = [for i in aws_subnet.private : i.id if contains(var.interface_endpoint_subnets, i.tags["Name"])]
}

######
# VPC
######
resource "aws_vpc" "this" {
  cidr_block                       = var.cidr
  instance_tenancy                 = var.instance_tenancy
  enable_dns_hostnames             = var.enable_dns_hostnames
  enable_dns_support               = var.enable_dns_support
  assign_generated_ipv6_cidr_block = var.assign_generated_ipv6_cidr_block
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  count = length(var.secondary_cidr_blocks) > 0 ? length(var.secondary_cidr_blocks) : 0

  vpc_id = aws_vpc.this.id

  cidr_block = element(var.secondary_cidr_blocks, count.index)
}

###################
# DHCP Options Set
###################
resource "aws_vpc_dhcp_options" "this" {
  count = var.enable_dhcp_options ? 1 : 0

  domain_name          = var.dhcp_options_domain_name
  domain_name_servers  = var.dhcp_options_domain_name_servers
  ntp_servers          = var.dhcp_options_ntp_servers
  netbios_name_servers = var.dhcp_options_netbios_name_servers
  netbios_node_type    = var.dhcp_options_netbios_node_type
}

###############################
# DHCP Options Set Association
###############################
resource "aws_vpc_dhcp_options_association" "this" {
  count = var.enable_dhcp_options ? 1 : 0

  vpc_id          = local.vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.this.0.id
}

###################
# Internet Gateway
###################
resource "aws_internet_gateway" "this" {
  count  = length(var.public_subnets) > 0 ? 1 : 0
  vpc_id = local.vpc_id
}

################
# Publiс routes
################
resource "aws_route_table" "public" {
  count  = length(var.public_subnets) > 0 ? 1 : 0
  vpc_id = local.vpc_id
}

resource "aws_route" "public_internet_gateway" {
  count                  = length(var.public_subnets) > 0 ? 1 : 0
  route_table_id         = aws_route_table.public.0.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.0.id

  timeouts {
    create = "5m"
  }
}

#################
# Private routes
#################
resource "aws_route_table" "private_ngw" {
  count = length(var.private_subnets) > 0 && var.enable_nat_gateway ? local.nat_gateway_count : 0

  vpc_id = local.vpc_id

  lifecycle {
    # When attaching VPN gateways it is common to define aws_vpn_gateway_route_propagation
    # resources that manipulate the attributes of the routing table (typically for the private subnets)
    ignore_changes = [propagating_vgws]
  }
}

resource "aws_route_table" "private_tgw" {
  count = var.transit_gateway_id != null ? 1 : 0

  vpc_id = local.vpc_id

  lifecycle {
    # When attaching VPN gateways it is common to define aws_vpn_gateway_route_propagation
    # resources that manipulate the attributes of the routing table (typically for the private subnets)
    ignore_changes = [propagating_vgws]
  }
}

resource "aws_route" "tgw_private" {
  count                  = var.transit_gateway_id != null ? 1 : 0
  route_table_id            = aws_route_table.private_tgw[0].id
  destination_cidr_block    = "10.0.0.0/8"
  transit_gateway_id        = var.transit_gateway_id
}

resource "aws_route" "internet_tgw" {
  count                  = var.transit_gateway_id != null ? 1 : 0
  route_table_id            = aws_route_table.private_tgw[0].id
  destination_cidr_block    = "0.0.0.0/0"
  transit_gateway_id        = var.transit_gateway_id
}

################
# Public subnet
################
resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = local.vpc_id
  cidr_block              = each.value.cidr_block
  availability_zone       = element(var.azs, each.value.availability_zone_index % length(var.azs))
  map_public_ip_on_launch = var.map_public_ip_on_launch
}



#################
# Private subnet
#################
resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = local.vpc_id
  cidr_block        = each.value.cidr_block
  availability_zone = element(var.azs, each.value.availability_zone_index % length(var.azs))
}

################
# NAT Gateways
################
locals {
  nat_gateway_ips = split(",", (var.reuse_nat_ips ? join(",", var.external_nat_ip_ids) : join(",", aws_eip.nat.*.id)))
}

resource "aws_eip" "nat" {
  count = (var.enable_nat_gateway && ! var.reuse_nat_ips) ? local.nat_gateway_count : 0
  vpc   = true
}

resource "aws_nat_gateway" "this" {
  count         = var.enable_nat_gateway ? local.nat_gateway_count : 0
  allocation_id = element(local.nat_gateway_ips, (var.single_nat_gateway ? 0 : count.index))
  subnet_id     = element([for subnet in aws_subnet.public : subnet.id], count.index)

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "private_nat_gateway" {
  count                  = var.enable_nat_gateway ? local.nat_gateway_count : 0
  route_table_id         = element(aws_route_table.private_ngw.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this.*.id, count.index)

  timeouts {
    create = "5m"
  }
}

######################
# VPC Endpoint for S3
######################
data "aws_vpc_endpoint_service" "s3" {
  count        = var.enable_s3_endpoint ? 1 : 0
  service      = "s3"
  service_type = "Gateway"
}

resource "aws_vpc_endpoint" "s3" {
  count        = var.enable_s3_endpoint ? 1 : 0
  vpc_id       = local.vpc_id
  service_name = data.aws_vpc_endpoint_service.s3.0.service_name
  tags         = var.tags
}

resource "aws_vpc_endpoint_route_table_association" "private_s3_ngw" {
  count           = var.enable_s3_endpoint && var.enable_nat_gateway ? local.nat_gateway_count : 0
  vpc_endpoint_id = aws_vpc_endpoint.s3.0.id
  route_table_id  = element(aws_route_table.private_ngw.*.id, count.index)
}

resource "aws_vpc_endpoint_route_table_association" "public_s3" {
  count           = var.enable_s3_endpoint && length(var.public_subnets) > 0 ? 1 : 0
  vpc_endpoint_id = aws_vpc_endpoint.s3.0.id
  route_table_id  = aws_route_table.public.0.id
}

resource "aws_vpc_endpoint_route_table_association" "private_s3_tgw" {
  count           = var.enable_s3_endpoint && var.transit_gateway_id != null ? 1 : 0
  vpc_endpoint_id = aws_vpc_endpoint.s3.0.id
  route_table_id  = element(aws_route_table.private_tgw.*.id, count.index)
}

######################
# VPC Endpoint for Glue
######################
data "aws_vpc_endpoint_service" "glue" {
  count   = var.enable_glue_endpoint ? 1 : 0
  service = "glue"
}

# resource "aws_vpc_endpoint" "glue" {
#   count               = var.enable_glue_endpoint ? 1 : 0
#   vpc_id              = local.vpc_id
#   service_name        = data.aws_vpc_endpoint_service.glue.0.service_name
#   vpc_endpoint_type   = "Interface"
#   security_group_ids  = [aws_security_group.glue_endpoint[0].id]
#   subnet_ids          = local.vpce_subnets
#   private_dns_enabled = true
#   tags                = var.tags
# }

resource "aws_security_group" "glue_endpoint" {
  count       = var.enable_glue_endpoint ? 1 : 0
  name        = "vpce_glue"
  description = "Allow instances to access Glue interface endpoint over HTTPS"
  vpc_id      = local.vpc_id
  tags        = merge({"Name"="vpce_glue"}, var.tags)
}

resource "aws_security_group_rule" "glue_endpoint_rule" {
  count             = var.enable_glue_endpoint ? 1 : 0
  description       = "Allow instances in this subnet to access Glue interface endpoint over HTTPS"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.glue_endpoint[0].id
  to_port           = 443
  type              = "ingress"
  cidr_blocks       = [for subnet in aws_subnet.private : subnet.cidr_block]
}

######################
# VPC Endpoint for KMS
######################
data "aws_vpc_endpoint_service" "kms" {
  count   = var.enable_kms_endpoint ? 1 : 0
  service = "kms"
}

resource "aws_vpc_endpoint" "kms" {
  count               = var.enable_kms_endpoint ? 1 : 0
  vpc_id              = local.vpc_id
  service_name        = data.aws_vpc_endpoint_service.kms.0.service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.kms_endpoint[0].id]
  subnet_ids          = local.vpce_subnets
  private_dns_enabled = true
  tags                = var.tags
}

# resource "aws_security_group" "kms_endpoint" {
#   count       = var.enable_kms_endpoint ? 1 : 0
#   name        = "vpce_kms"
#   description = "Allow instances to access KMS interface endpoint over HTTPS"
#   vpc_id      = local.vpc_id
# }

resource "aws_security_group_rule" "kms_endpoint_rule" {
  count             = var.enable_kms_endpoint ? 1 : 0
  description       = "Allow instances in this subnet to access KMS interface endpoint over HTTPS"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.kms_endpoint[0].id
  to_port           = 443
  type              = "ingress"
  cidr_blocks       = [for subnet in aws_subnet.private : subnet.cidr_block]
}

####################################
# VPC Endpoint for Secrets Manager
####################################
# data "aws_vpc_endpoint_service" "secrets" {
#   count   = var.enable_secrets_endpoint ? 1 : 0
#   service = "secretsmanager"
# }

# resource "aws_vpc_endpoint" "secrets" {
#   count               = var.enable_secrets_endpoint ? 1 : 0
#   vpc_id              = local.vpc_id
#   service_name        = data.aws_vpc_endpoint_service.secrets.0.service_name
#   vpc_endpoint_type   = "Interface"
#   security_group_ids  = [aws_security_group.secrets_endpoint[0].id]
#   subnet_ids          = local.vpce_subnets
#   private_dns_enabled = true
#   tags                = var.tags
# }

# resource "aws_security_group" "secrets_endpoint" {
#   count       = var.enable_secrets_endpoint ? 1 : 0
#   name        = "vpce_secrets"
#   description = "Allow instances to access Secrets interface endpoint over HTTPS"
#   vpc_id      = local.vpc_id
# }

# resource "aws_security_group_rule" "secrets_endpoint_rule" {
#   count             = var.enable_secrets_endpoint ? 1 : 0
#   description       = "Allow instances in this subnet to access secrets interface endpoint over HTTPS"
#   from_port         = 443
#   protocol          = "tcp"
#   security_group_id = aws_security_group.secrets_endpoint[0].id
#   to_port           = 443
#   type              = "ingress"
#   cidr_blocks       = [for subnet in aws_subnet.private : subnet.cidr_block]
# }

####################################
# VPC Endpoint for SNS
####################################
# data "aws_vpc_endpoint_service" "sns" {
#   count   = var.enable_sns_endpoint ? 1 : 0
#   service = "sns"
# }

# resource "aws_vpc_endpoint" "sns" {
#   count               = var.enable_sns_endpoint ? 1 : 0
#   vpc_id              = local.vpc_id
#   service_name        = data.aws_vpc_endpoint_service.sns.0.service_name
#   vpc_endpoint_type   = "Interface"
#   security_group_ids  = [aws_security_group.sns_endpoint[0].id]
#   subnet_ids          = local.vpce_subnets
#   private_dns_enabled = true
#   tags                = var.tags
# }

# resource "aws_security_group" "sns_endpoint" {
#   count       = var.enable_sns_endpoint ? 1 : 0
#   name        = "vpce_sns"
#   description = "Allow instances to access SNS interface endpoint over HTTPS"
#   vpc_id      = local.vpc_id
# }

# resource "aws_security_group_rule" "sns_endpoint_rule" {
#   count             = var.enable_sns_endpoint ? 1 : 0
#   description       = "Allow instances in this subnet to access SNS interface endpoint over HTTPS"
#   from_port         = 443
#   protocol          = "tcp"
#   security_group_id = aws_security_group.sns_endpoint[0].id
#   to_port           = 443
#   type              = "ingress"
#   cidr_blocks       = [for subnet in aws_subnet.private : subnet.cidr_block]
# }

# ############################
# # VPC Endpoint for DynamoDB
# ############################
# data "aws_vpc_endpoint_service" "dynamodb" {
#   count   = var.enable_dynamodb_endpoint ? 1 : 0
#   service = "dynamodb"
# }

# resource "aws_vpc_endpoint" "dynamodb" {
#   count        = var.enable_dynamodb_endpoint ? 1 : 0
#   vpc_id       = local.vpc_id
#   service_name = data.aws_vpc_endpoint_service.dynamodb.0.service_name
#   tags         = var.tags
# }

# resource "aws_vpc_endpoint_route_table_association" "private_dynamodb_ngw" {
#   count           = var.enable_dynamodb_endpoint && var.enable_nat_gateway ? local.nat_gateway_count : 0
#   vpc_endpoint_id = aws_vpc_endpoint.dynamodb.0.id
#   route_table_id  = element(aws_route_table.private_ngw.*.id, count.index)
# }

# resource "aws_vpc_endpoint_route_table_association" "public_dynamodb" {
#   count           = var.enable_dynamodb_endpoint && length(var.public_subnets) > 0 ? 1 : 0
#   vpc_endpoint_id = aws_vpc_endpoint.dynamodb.0.id
#   route_table_id  = aws_route_table.public.0.id
# }

# resource "aws_vpc_endpoint_route_table_association" "private_dynamodb_tgw" {
#   count           = var.enable_dynamodb_endpoint && var.transit_gateway_id != null ? 1 : 0
#   vpc_endpoint_id = aws_vpc_endpoint.dynamodb.0.id
#   route_table_id  = element(aws_route_table.private_tgw.*.id, count.index)
# }

# ############################
# # VPC Endpoints for Session Manager
# ############################
# data "aws_vpc_endpoint_service" "session_manager" {
#   service = "ssm"
# }

# data "aws_vpc_endpoint_service" "session_manager_messages" {
#   service = "ssmmessages"
# }

# data "aws_vpc_endpoint_service" "ec2_messages" {
#   service = "ec2messages"
# }

# resource "aws_vpc_endpoint" "session_manager" {
#   count               = var.enable_session_manager_endpoints ? 1 : 0
#   service_name        = data.aws_vpc_endpoint_service.session_manager.service_name
#   vpc_id              = local.vpc_id
#   vpc_endpoint_type   = "Interface"
#   security_group_ids  = [aws_security_group.ssm_endpoint[0].id]
#   subnet_ids          = local.vpce_subnets
#   private_dns_enabled = true
#   tags                = var.tags
# }

# resource "aws_vpc_endpoint" "session_manager_messages" {
#   count               = var.enable_session_manager_endpoints ? 1 : 0
#   service_name        = data.aws_vpc_endpoint_service.session_manager_messages.service_name
#   vpc_id              = local.vpc_id
#   vpc_endpoint_type   = "Interface"
#   security_group_ids  = [aws_security_group.ssm_endpoint[0].id]
#   subnet_ids          = local.vpce_subnets
#   private_dns_enabled = true
#   tags                = var.tags
# }

# resource "aws_vpc_endpoint" "ec2_messages" {
#   count               = var.enable_session_manager_endpoints ? 1 : 0
#   service_name        = data.aws_vpc_endpoint_service.ec2_messages.service_name
#   vpc_id              = local.vpc_id
#   vpc_endpoint_type   = "Interface"
#   security_group_ids  = [aws_security_group.ssm_endpoint[0].id]
#   subnet_ids          = local.vpce_subnets
#   private_dns_enabled = true
#   tags                = var.tags
# }

# resource "aws_security_group" "ssm_endpoint" {
#   count       = var.enable_session_manager_endpoints ? 1 : 0
#   name        = "vpce_session_manager"
#   description = "Allow instances to access Session Manager interface endpoints over HTTPS"
#   vpc_id      = local.vpc_id
# }

# resource "aws_security_group_rule" "ssm_endpoint_rule" {
#   count             = var.enable_session_manager_endpoints ? 1 : 0
#   description       = "Allow instances in this subnet to access Session Manager interface endpoints over HTTPS"
#   from_port         = 443
#   protocol          = "tcp"
#   security_group_id = aws_security_group.ssm_endpoint[0].id
#   to_port           = 443
#   type              = "ingress"
#   cidr_blocks       = [for subnet in aws_subnet.private : subnet.cidr_block]
# }

# ###################################
# # VPC Endpoint for STS
# ####################################
# data "aws_vpc_endpoint_service" "sts" {
#   count   = var.enable_sts_endpoint ? 1 : 0
#   service = "sts"
# }

# resource "aws_vpc_endpoint" "sts" {
#   count               = var.enable_sts_endpoint ? 1 : 0
#   vpc_id              = local.vpc_id
#   service_name        = data.aws_vpc_endpoint_service.sts.0.service_name
#   vpc_endpoint_type   = "Interface"
#   security_group_ids  = [aws_security_group.sts_endpoint[0].id]
#   subnet_ids          = local.vpce_subnets
#   private_dns_enabled = true
#   tags                = var.tags
# }

# resource "aws_security_group" "sts_endpoint" {
#   count       = var.enable_sts_endpoint ? 1 : 0
#   name        = "vpce_sts"
#   description = "Allow instances to access STS interface endpoint over HTTPS"
#   vpc_id      = local.vpc_id
# }

# resource "aws_security_group_rule" "sts_endpoint_rule" {
#   count             = var.enable_sts_endpoint ? 1 : 0
#   description       = "Allow instances in this subnet to access STS interface endpoint over HTTPS"
#   from_port         = 443
#   protocol          = "tcp"
#   security_group_id = aws_security_group.sts_endpoint[0].id
#   to_port           = 443
#   type              = "ingress"
#   cidr_blocks       = [for subnet in aws_subnet.private : subnet.cidr_block]
# }


# ######################
# # Generic VPC Interface Endpoints
# ######################

# data "aws_vpc_endpoint_service" "vpc_interface_endpoints" {
#   for_each = toset(var.vpc_interface_endpoints)
#   service = each.key
# }

# resource "aws_vpc_endpoint" "vpc_interface_endpoints" {
#   for_each            = toset(var.vpc_interface_endpoints)
#   vpc_id              = local.vpc_id
#   service_name        = data.aws_vpc_endpoint_service.vpc_interface_endpoints[each.key].service_name
#   vpc_endpoint_type   = "Interface"
#   private_dns_enabled = true
#   subnet_ids          = local.vpce_subnets
#   security_group_ids  = [aws_security_group.vpc_interface_endpoints[each.key].id]
# }

# resource "aws_security_group" "vpc_interface_endpoints" {
#   for_each    = toset(var.vpc_interface_endpoints)
#   name        = "vpce_${each.key}"
#   description = "Allow instances to access ${each.key} interface endpoint over HTTPS"
#   vpc_id      = local.vpc_id
# }

# resource "aws_security_group_rule" "vpc_interface_endpoints" {
#   for_each          = toset(var.vpc_interface_endpoints)
#   description       = "Allow instances in this subnet to access ${each.key} interface endpoint over HTTPS"
#   from_port         = 443
#   to_port           = 443
#   type              = "ingress"
#   protocol          = "tcp"
#   cidr_blocks       = [for subnet in aws_subnet.private : subnet.cidr_block]
#   security_group_id = aws_security_group.vpc_interface_endpoints[each.key].id
# }

##########################
# Route table association
##########################
resource "aws_route_table_association" "private_ngw" {
  for_each       = var.enable_nat_gateway ? var.private_subnets : {}
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private_ngw[each.value.availability_zone_index].id
}

resource "aws_route_table_association" "public" {
  for_each       = var.public_subnets
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.0.id
}

resource "aws_route_table_association" "private_tgw" {
  for_each          = var.transit_gateway_id != null ? var.private_subnets : {}
  subnet_id         = aws_subnet.private[each.key].id
  route_table_id    = aws_route_table.private_tgw.0.id
}

##############
# VPN Gateway
##############
resource "aws_vpn_gateway" "this" {
  count           = var.enable_vpn_gateway ? 1 : 0
  vpc_id          = local.vpc_id
  amazon_side_asn = var.amazon_side_asn
}

resource "aws_vpn_gateway_attachment" "this" {
  count          = var.vpn_gateway_id != "" ? 1 : 0
  vpc_id         = local.vpc_id
  vpn_gateway_id = var.vpn_gateway_id
}

resource "aws_vpn_gateway_route_propagation" "public" {
  count          = var.propagate_public_route_tables_vgw && (var.enable_vpn_gateway || var.vpn_gateway_id != "") ? 1 : 0
  route_table_id = element(aws_route_table.public.*.id, count.index)
  vpn_gateway_id = element(concat(aws_vpn_gateway.this.*.id, aws_vpn_gateway_attachment.this.*.vpn_gateway_id), count.index)
}

resource "aws_vpn_gateway_route_propagation" "private" {
  count          = var.propagate_private_route_tables_vgw && (var.enable_vpn_gateway || var.vpn_gateway_id != "") ? length(var.private_subnets) : 0
  route_table_id = element(aws_route_table.private_ngw.*.id, count.index)
  vpn_gateway_id = element(concat(aws_vpn_gateway.this.*.id, aws_vpn_gateway_attachment.this.*.vpn_gateway_id), count.index)
}

###########
# Defaults
###########
resource "aws_default_vpc" "this" {
  count                = var.manage_default_vpc ? 1 : 0
  enable_dns_support   = var.default_vpc_enable_dns_support
  enable_dns_hostnames = var.default_vpc_enable_dns_hostnames
  enable_classiclink   = var.default_vpc_enable_classiclink
}

resource "aws_default_security_group" "default" {
  count  = var.manage_default_sg ? 1 : 0
  vpc_id = local.vpc_id
  tags   = var.tags
}
