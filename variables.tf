variable "name" {
  description = "Name to be used on all the resources as identifier"
  default     = ""
}

variable "cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  default     = "0.0.0.0/0"
}

variable "assign_generated_ipv6_cidr_block" {
  description = "Requests an Amazon-provided IPv6 CIDR block with a /56 prefix length for the VPC. You cannot specify the range of IP addresses, or the size of the CIDR block"
  default     = false
}

variable "secondary_cidr_blocks" {
  description = "List of secondary CIDR blocks to associate with the VPC to extend the IP Address pool"
  default     = []
}

variable "instance_tenancy" {
  description = "A tenancy option for instances launched into the VPC"
  default     = "default"
}

variable "public_subnet_suffix" {
  description = "Suffix to append to public subnets name"
  default     = "public"
}

variable "private_subnet_suffix" {
  description = "Suffix to append to private subnets name"
  default     = "private"
}

variable "public_subnets" {
  description = "A map of public subnets and their ranges"
  type        = map
  default     = {}
}

variable "private_subnets" {
  description = "A map of private subnets and their ranges"
  type        = map
  default     = {}
}

variable "azs" {
  description = "A list of availability zones in the region"
  default     = []
}

variable "enable_dns_hostnames" {
  description = "Should be true to enable DNS hostnames in the VPC"
  default     = true
}

variable "enable_dns_support" {
  description = "Should be true to enable DNS support in the VPC"
  default     = true
}

variable "enable_nat_gateway" {
  description = "Should be true if you want to provision NAT Gateways for each of your private networks"
  default     = false
}

variable "single_nat_gateway" {
  description = "Should be true if you want to provision a single shared NAT Gateway across all of your private networks"
  default     = false
}

variable "one_nat_gateway_per_az" {
  description = "Should be true if you want only one NAT Gateway per availability zone. Requires `var.azs` to be set, and the number of `public_subnets` created to be greater than or equal to the number of availability zones specified in `var.azs`."
  default     = true
}

variable "reuse_nat_ips" {
  description = "Should be true if you don't want EIPs to be created for your NAT Gateways and will instead pass them in via the 'external_nat_ip_ids' variable"
  default     = false
}

variable "external_nat_ip_ids" {
  description = "List of EIP IDs to be assigned to the NAT Gateways (used in combination with reuse_nat_ips)"
  type        = list
  default     = []
}

variable "enable_dynamodb_endpoint" {
  description = "Should be true if you want to provision a DynamoDB endpoint to the VPC"
  default     = false
}

variable "enable_glue_endpoint" {
  description = "Should be true if you want to provision a Glue endpoint to the VPC"
  default     = false
}

variable "enable_kms_endpoint" {
  description = "Should be true if you want to provision a KMS endpoint to the VPC"
  default     = false
}

variable "enable_secrets_endpoint" {
  description = "Should be true if you want to provision a secrets endpoint to the VPC"
  default     = false
}

variable "enable_sns_endpoint" {
  description = "Should be true if you want to provision an SNS endpoint to the VPC"
  default     = false
}

variable "enable_sts_endpoint" {
  description = "Should be true if you want to provision an STS endpoint to the VPC"
  default     = false
}

variable "enable_s3_endpoint" {
  description = "Should be true if you want to provision an S3 endpoint to the VPC"
  default     = false
}

variable "enable_session_manager_endpoints" {
  description = "Should be true if you want to connect to EC2 instances, false if you don't plan on running EC2 instances"
  default     = false
}

# WE SHOULD RECACTOR THE ABOVE SERVICES OUT IN FAVOR OF THIS VAR
variable "vpc_interface_endpoints" {
  description = "List of services to enable VPC endpoints for"
  default     = []
}

variable "map_public_ip_on_launch" {
  description = "Should be false if you do not want to auto-assign public IP on launch"
  default     = false
}

variable "enable_vpn_gateway" {
  description = "Should be true if you want to create a new VPN Gateway resource and attach it to the VPC"
  default     = false
}

variable "vpn_gateway_id" {
  description = "ID of VPN Gateway to attach to the VPC"
  default     = ""
}

variable "amazon_side_asn" {
  description = "The Autonomous System Number (ASN) for the Amazon side of the gateway. By default the virtual private gateway is created with the current default Amazon ASN."
  default     = "64512"
}

variable "propagate_private_route_tables_vgw" {
  description = "Should be true if you want route table propagation"
  default     = false
}

variable "propagate_public_route_tables_vgw" {
  description = "Should be true if you want route table propagation"
  default     = false
}

variable "tags" {
  description = "A map of tags to add to all resources"
}

variable "vpc_tags" {
  description = "Additional tags for the VPC"
  default     = {}
}

variable "igw_tags" {
  description = "Additional tags for the internet gateway"
  default     = {}
}

variable "public_subnet_tags" {
  description = "Additional tags for the public subnets"
  default     = {}
}

variable "private_subnet_tags" {
  description = "Additional tags for the private subnets"
  default     = {}
}

variable "public_route_table_tags" {
  description = "Additional tags for the public route tables"
  default     = {}
}

variable "private_route_table_tags" {
  description = "Additional tags for the private route tables"
  default     = {}
}

variable "database_route_table_tags" {
  description = "Additional tags for the database route tables"
  default     = {}
}

variable "redshift_route_table_tags" {
  description = "Additional tags for the redshift route tables"
  default     = {}
}

variable "elasticache_route_table_tags" {
  description = "Additional tags for the elasticache route tables"
  default     = {}
}

variable "intra_route_table_tags" {
  description = "Additional tags for the intra route tables"
  default     = {}
}

variable "database_subnet_tags" {
  description = "Additional tags for the database subnets"
  default     = {}
}

variable "database_subnet_group_tags" {
  description = "Additional tags for the database subnet group"
  default     = {}
}

variable "redshift_subnet_tags" {
  description = "Additional tags for the redshift subnets"
  default     = {}
}

variable "redshift_subnet_group_tags" {
  description = "Additional tags for the redshift subnet group"
  default     = {}
}

variable "elasticache_subnet_tags" {
  description = "Additional tags for the elasticache subnets"
  default     = {}
}

variable "intra_subnet_tags" {
  description = "Additional tags for the intra subnets"
  default     = {}
}

variable "dhcp_options_tags" {
  description = "Additional tags for the DHCP option set"
  default     = {}
}

variable "nat_gateway_tags" {
  description = "Additional tags for the NAT gateways"
  default     = {}
}

variable "nat_eip_tags" {
  description = "Additional tags for the NAT EIP"
  default     = {}
}

variable "vpn_gateway_tags" {
  description = "Additional tags for the VPN gateway"
  default     = {}
}

variable "enable_dhcp_options" {
  description = "Should be true if you want to specify a DHCP options set with a custom domain name, DNS servers, NTP servers, netbios servers, and/or netbios server type"
  default     = false
}

variable "dhcp_options_domain_name" {
  description = "Specifies DNS name for DHCP options set"
  default     = null
}

variable "dhcp_options_domain_name_servers" {
  description = "Specify a list of DNS server addresses for DHCP options set, default to AWS provided"
  type        = list
  default     = []
}

variable "dhcp_options_ntp_servers" {
  description = "Specify a list of NTP servers for DHCP options set"
  type        = list
  default     = []
}

variable "dhcp_options_netbios_name_servers" {
  description = "Specify a list of netbios servers for DHCP options set"
  type        = list
  default     = []
}

variable "dhcp_options_netbios_node_type" {
  description = "Specify netbios node_type for DHCP options set"
  default     = ""
}

variable "manage_default_vpc" {
  description = "Should be true to adopt and manage Default VPC"
  default     = false
}

variable "default_vpc_name" {
  description = "Name to be used on the Default VPC"
  default     = ""
}

variable "default_vpc_enable_dns_support" {
  description = "Should be true to enable DNS support in the Default VPC"
  default     = true
}

variable "default_vpc_enable_dns_hostnames" {
  description = "Should be true to enable DNS hostnames in the Default VPC"
  default     = false
}

variable "default_vpc_enable_classiclink" {
  description = "Should be true to enable ClassicLink in the Default VPC"
  default     = false
}

variable "default_vpc_tags" {
  description = "Additional tags for the Default VPC"
  default     = {}
}

variable "vpc_flowlogs_cloudwatch_destination_arn" {
  description = "The ARN of the CloudWatch Destination to receive VPC Flowlogs for a particular region"
  default     = null
}

variable "encrypt_flow_logs" {
  description = "Create a KMS key and encrypt the flowlogs cloudwatch log group"
  default     = true
}

variable "manage_default_sg" {
  description = "Take over management of default security group"
  default     = true
}

variable "interface_endpoint_subnets" {
  description = "Subnets where VPC interface endpoints live"
  default     = []
}

variable "flowlog_format" {
  description = "Format to be used for VPC flow logs."
  default     = null
}

variable "log_group_retention_in_days" {
  default     = 365
  description = "retention in days for cloudwatch log groups"
}

variable "transit_gateway_id" {
  description = "The id of the transit gateway in the spoke account"
  default     = null
}
