![Terraform GitHub Actions](https://github.com/tlzproject/core-account-request-form/workflows/Terraform%20GitHub%20Actions/badge.svg)

# AWS VPC Terraform module

Terraform module which creates VPC resources on AWS.

These types of resources are supported:

* [VPC](https://www.terraform.io/docs/providers/aws/r/vpc.html)
* [Subnet](https://www.terraform.io/docs/providers/aws/r/subnet.html)
* [Route](https://www.terraform.io/docs/providers/aws/r/route.html)
* [Route table](https://www.terraform.io/docs/providers/aws/r/route_table.html)
* [Internet Gateway](https://www.terraform.io/docs/providers/aws/r/internet_gateway.html)
* [NAT Gateway](https://www.terraform.io/docs/providers/aws/r/nat_gateway.html)
* [VPN Gateway](https://www.terraform.io/docs/providers/aws/r/vpn_gateway.html)
* [VPC Endpoint](https://www.terraform.io/docs/providers/aws/r/vpc_endpoint.html) (S3 and DynamoDB)
* [RDS DB Subnet Group](https://www.terraform.io/docs/providers/aws/r/db_subnet_group.html)
* [ElastiCache Subnet Group](https://www.terraform.io/docs/providers/aws/r/elasticache_subnet_group.html)
* [Redshift Subnet Group](https://www.terraform.io/docs/providers/aws/r/redshift_subnet_group.html)
* [DHCP Options Set](https://www.terraform.io/docs/providers/aws/r/vpc_dhcp_options.html)
* [Default VPC](https://www.terraform.io/docs/providers/aws/r/default_vpc.html)

## Usage

```hcl
module "vpc" {
  source = "tfe.hosting.com/cloudops/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets = {
    "private-a" = {
      cidr_block              = "10.0.1.0/24",
      availability_zone_index = 0
    },
    "private-b" = {
      cidr_block              = "10.0.2.0/24",
      availability_zone_index = 1
    },
    "private-c" = {
      cidr_block              = "10.0.2.0/24",
      availability_zone_index = 2
    }
  }
  public_subnets = {
    "public-a" = {
      cidr_block              = "10.0.101.0/24",
      availability_zone_index = 0
    },
    "public-b" = {
      cidr_block              = "10.0.102.0/24",
      availability_zone_index = 1
    },
    "public-c" = {
      cidr_block              = "10.0.103.0/24",
      availability_zone_index = 2
    }
  }

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}
```

## External NAT Gateway IPs

By default this module will provision new Elastic IPs for the VPC's NAT Gateways.
This means that when creating a new VPC, new IPs are allocated, and when that VPC is destroyed those IPs are released.
Sometimes it is handy to keep the same IPs even after the VPC is destroyed and re-created.
To that end, it is possible to assign existing IPs to the NAT Gateways.
This prevents the destruction of the VPC from releasing those IPs, while making it possible that a re-created VPC uses the same IPs.

To achieve this, allocate the IPs outside the VPC module declaration.
```hcl
resource "aws_eip" "nat" {
  count = 3

  vpc = true
}
```

Then, pass the allocated IPs as a parameter to this module.
```hcl
module "vpc" {
  source = "tfe.hosting.com/cloudops/vpc/aws"

  # The rest of arguments are omitted for brevity

  enable_nat_gateway  = true
  single_nat_gateway  = false
  reuse_nat_ips       = true                      # <= Skip creation of EIPs for the NAT Gateways
  external_nat_ip_ids = [aws_eip.nat.*.id]   # <= IPs specified here as input to the module
}
```

Note that in the example we allocate 3 IPs because we will be provisioning 3 NAT Gateways (due to `single_nat_gateway = false` and having 3 subnets).
If, on the other hand, `single_nat_gateway = true`, then `aws_eip.nat` would only need to allocate 1 IP.
Passing the IPs into the module is done by setting two variables `reuse_nat_ips = true` and `external_nat_ip_ids = ["${aws_eip.nat.*.id}"]`.

## NAT Gateway Scenarios

This module supports three scenarios for creating NAT gateways. Each will be explained in further detail in the corresponding sections.

* One NAT Gateway per subnet (default behavior)
    * `enable_nat_gateway = true`
    * `single_nat_gateway = false`
    * `one_nat_gateway_per_az = false`
* Single NAT Gateway
    * `enable_nat_gateway = true`
    * `single_nat_gateway = true`
    * `one_nat_gateway_per_az = false`
* One NAT Gateway per availability zone
    * `enable_nat_gateway = true`
    * `single_nat_gateway = false`
    * `one_nat_gateway_per_az = true`

If both `single_nat_gateway` and `one_nat_gateway_per_az` are set to `true`, then `single_nat_gateway` takes precedence.

### Single NAT Gateway

If `single_nat_gateway = true`, then all private subnets will route their Internet traffic through this single NAT gateway. The NAT gateway will be placed in the first public subnet in your `public_subnets` block.

### One NAT Gateway per availability zone

If `one_nat_gateway_per_az = true` and `single_nat_gateway = false`, then the module will place one NAT gateway in each availability zone you specify in `var.azs`. There are some requirements around using this feature flag:

* The variable `var.azs` **must** be specified.
* The number of public subnet CIDR blocks specified in `public_subnets` **must** be greater than or equal to the number of availability zones specified in `var.azs`. This is to ensure that each NAT Gateway has a dedicated public subnet to deploy to.


## Terraform version

Terraform version 0.12.0 or newer is required for this module to work.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| amazon\_side\_asn | The Autonomous System Number (ASN) for the Amazon side of the gateway. By default the virtual private gateway is created with the current default Amazon ASN. | string | `64512` | no |
| assign\_generated\_ipv6\_cidr\_block | Requests an Amazon-provided IPv6 CIDR block with a /56 prefix length for the VPC. You cannot specify the range of IP addresses, or the size of the CIDR block | string | `false` | no |
| azs | A list of availability zones in the region | list | `<list>` | no |
| cidr | The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden | string | `0.0.0.0/0` | no |
| create\_database\_subnet\_group | Controls if database subnet group should be created | string | `true` | no |
| create\_database\_subnet\_route\_table | Controls if separate route table for database should be created | string | `false` | no |
| create\_elasticache\_subnet\_route\_table | Controls if separate route table for elasticache should be created | string | `false` | no |
| create\_redshift\_subnet\_route\_table | Controls if separate route table for redshift should be created | string | `false` | no |
| create\_vpc | Controls if VPC should be created (it affects almost all resources) | string | `true` | no |
| database\_route\_table\_tags | Additional tags for the database route tables | map | `<map>` | no |
| database\_subnet\_group\_tags | Additional tags for the database subnet group | map | `<map>` | no |
| database\_subnet\_suffix | Suffix to append to database subnets name | string | `db` | no |
| database\_subnet\_tags | Additional tags for the database subnets | map | `<map>` | no |
| database\_subnets | A list of database subnets | list | `<list>` | no |
| default\_vpc\_enable\_classiclink | Should be true to enable ClassicLink in the Default VPC | string | `false` | no |
| default\_vpc\_enable\_dns\_hostnames | Should be true to enable DNS hostnames in the Default VPC | string | `false` | no |
| default\_vpc\_enable\_dns\_support | Should be true to enable DNS support in the Default VPC | string | `true` | no |
| default\_vpc\_name | Name to be used on the Default VPC | string | `` | no |
| default\_vpc\_tags | Additional tags for the Default VPC | map | `<map>` | no |
| dhcp\_options\_domain\_name | Specifies DNS name for DHCP options set | string | `` | no |
| dhcp\_options\_domain\_name\_servers | Specify a list of DNS server addresses for DHCP options set, default to AWS provided | list | `<list>` | no |
| dhcp\_options\_netbios\_name\_servers | Specify a list of netbios servers for DHCP options set | list | `<list>` | no |
| dhcp\_options\_netbios\_node\_type | Specify netbios node_type for DHCP options set | string | `` | no |
| dhcp\_options\_ntp\_servers | Specify a list of NTP servers for DHCP options set | list | `<list>` | no |
| dhcp\_options\_tags | Additional tags for the DHCP option set | map | `<map>` | no |
| elasticache\_route\_table\_tags | Additional tags for the elasticache route tables | map | `<map>` | no |
| elasticache\_subnet\_suffix | Suffix to append to elasticache subnets name | string | `elasticache` | no |
| elasticache\_subnet\_tags | Additional tags for the elasticache subnets | map | `<map>` | no |
| elasticache\_subnets | A list of elasticache subnets | list | `<list>` | no |
| enable\_dhcp\_options | Should be true if you want to specify a DHCP options set with a custom domain name, DNS servers, NTP servers, netbios servers, and/or netbios server type | string | `false` | no |
| enable\_dns\_hostnames | Should be true to enable DNS hostnames in the VPC | string | `false` | no |
| enable\_dns\_support | Should be true to enable DNS support in the VPC | string | `true` | no |
| enable\_dynamodb\_endpoint | Should be true if you want to provision a DynamoDB endpoint to the VPC | string | `false` | no |
| enable\_nat\_gateway | Should be true if you want to provision NAT Gateways for each of your private networks | string | `false` | no |
| enable\_s3\_endpoint | Should be true if you want to provision an S3 endpoint to the VPC | string | `false` | no |
| enable\_vpn\_gateway | Should be true if you want to create a new VPN Gateway resource and attach it to the VPC | string | `false` | no |
| external\_nat\_ip\_ids | List of EIP IDs to be assigned to the NAT Gateways (used in combination with reuse_nat_ips) | list | `<list>` | no |
| igw\_tags | Additional tags for the internet gateway | map | `<map>` | no |
| instance\_tenancy | A tenancy option for instances launched into the VPC | string | `default` | no |
| intra\_route\_table\_tags | Additional tags for the intra route tables | map | `<map>` | no |
| intra\_subnet\_tags | Additional tags for the intra subnets | map | `<map>` | no |
| intra\_subnets | A list of intra subnets | list | `<list>` | no |
| manage\_default\_vpc | Should be true to adopt and manage Default VPC | string | `false` | no |
| map\_public\_ip\_on\_launch | Should be false if you do not want to auto-assign public IP on launch | string | `true` | no |
| name | Name to be used on all the resources as identifier | string | `` | no |
| nat\_eip\_tags | Additional tags for the NAT EIP | map | `<map>` | no |
| nat\_gateway\_tags | Additional tags for the NAT gateways | map | `<map>` | no |
| one\_nat\_gateway\_per\_az | Should be true if you want only one NAT Gateway per availability zone. Requires `var.azs` to be set, and the number of `public_subnets` created to be greater than or equal to the number of availability zones specified in `var.azs`. | string | `false` | no |
| private\_route\_table\_tags | Additional tags for the private route tables | map | `<map>` | no |
| private\_subnet\_suffix | Suffix to append to private subnets name | string | `private` | no |
| private\_subnet\_tags | Additional tags for the private subnets | map | `<map>` | no |
| private\_subnets | A list of private subnets inside the VPC | list | `<list>` | no |
| propagate\_private\_route\_tables\_vgw | Should be true if you want route table propagation | string | `false` | no |
| propagate\_public\_route\_tables\_vgw | Should be true if you want route table propagation | string | `false` | no |
| public\_route\_table\_tags | Additional tags for the public route tables | map | `<map>` | no |
| public\_subnet\_suffix | Suffix to append to public subnets name | string | `public` | no |
| public\_subnet\_tags | Additional tags for the public subnets | map | `<map>` | no |
| public\_subnets | A list of public subnets inside the VPC | list | `<list>` | no |
| redshift\_route\_table\_tags | Additional tags for the redshift route tables | map | `<map>` | no |
| redshift\_subnet\_group\_tags | Additional tags for the redshift subnet group | map | `<map>` | no |
| redshift\_subnet\_suffix | Suffix to append to redshift subnets name | string | `redshift` | no |
| redshift\_subnet\_tags | Additional tags for the redshift subnets | map | `<map>` | no |
| redshift\_subnets | A list of redshift subnets | list | `<list>` | no |
| reuse\_nat\_ips | Should be true if you don't want EIPs to be created for your NAT Gateways and will instead pass them in via the 'external_nat_ip_ids' variable | string | `false` | no |
| secondary\_cidr\_blocks | List of secondary CIDR blocks to associate with the VPC to extend the IP Address pool | list | `<list>` | no |
| single\_nat\_gateway | Should be true if you want to provision a single shared NAT Gateway across all of your private networks | string | `false` | no |
| tags | A map of tags to add to all resources | map | `<map>` | no |
| vpc\_flowlogs\_cloudwatch\_destination\_arn | The ARN of the CloudWatch Destination to receive VPC Flowlogs for a particular region | string | - | yes |
| vpc\_tags | Additional tags for the VPC | map | `<map>` | no |
| vpn\_gateway\_id | ID of VPN Gateway to attach to the VPC | string | `` | no |
| vpn\_gateway\_tags | Additional tags for the VPN gateway | map | `<map>` | no |

## Outputs

| Name | Description |
|------|-------------|
| database\_route\_table\_ids | List of IDs of database route tables |
| database\_subnet\_group | ID of database subnet group |
| database\_subnets | List of IDs of database subnets |
| database\_subnets\_cidr\_blocks | List of cidr_blocks of database subnets |
| default\_network\_acl\_id | The ID of the default network ACL |
| default\_route\_table\_id | The ID of the default route table |
| default\_security\_group\_id | The ID of the security group created by default on VPC creation |
| default\_vpc\_cidr\_block | The CIDR block of the VPC |
| default\_vpc\_default\_network\_acl\_id | The ID of the default network ACL |
| default\_vpc\_default\_route\_table\_id | The ID of the default route table |
| default\_vpc\_default\_security\_group\_id | The ID of the security group created by default on VPC creation |
| default\_vpc\_enable\_dns\_hostnames | Whether or not the VPC has DNS hostname support |
| default\_vpc\_enable\_dns\_support | Whether or not the VPC has DNS support |
| default\_vpc\_id | The ID of the VPC |
| default\_vpc\_instance\_tenancy | Tenancy of instances spin up within VPC |
| default\_vpc\_main\_route\_table\_id | The ID of the main route table associated with this VPC |
| elasticache\_route\_table\_ids | List of IDs of elasticache route tables |
| elasticache\_subnet\_group | ID of elasticache subnet group |
| elasticache\_subnet\_group\_name | Name of elasticache subnet group |
| elasticache\_subnets | List of IDs of elasticache subnets |
| elasticache\_subnets\_cidr\_blocks | List of cidr_blocks of elasticache subnets |
| igw\_id | The ID of the Internet Gateway |
| intra\_route\_table\_ids | List of IDs of intra route tables |
| intra\_subnets | List of IDs of intra subnets |
| intra\_subnets\_cidr\_blocks | List of cidr_blocks of intra subnets |
| nat\_ids | List of allocation ID of Elastic IPs created for AWS NAT Gateway |
| nat\_public\_ips | List of public Elastic IPs created for AWS NAT Gateway |
| natgw\_ids | List of NAT Gateway IDs |
| private\_route\_table\_ids | List of IDs of private route tables |
| private\_subnets | List of IDs of private subnets |
| private\_subnets\_cidr\_blocks | List of cidr_blocks of private subnets |
| public\_route\_table\_ids | List of IDs of public route tables |
| public\_subnets | List of IDs of public subnets |
| public\_subnets\_cidr\_blocks | List of cidr_blocks of public subnets |
| redshift\_route\_table\_ids | List of IDs of redshift route tables |
| redshift\_subnet\_group | ID of redshift subnet group |
| redshift\_subnets | List of IDs of redshift subnets |
| redshift\_subnets\_cidr\_blocks | List of cidr_blocks of redshift subnets |
| vgw\_id | The ID of the VPN Gateway |
| vpc\_cidr\_block | The CIDR block of the VPC |
| vpc\_enable\_dns\_hostnames | Whether or not the VPC has DNS hostname support |
| vpc\_enable\_dns\_support | Whether or not the VPC has DNS support |
| vpc\_endpoint\_dynamodb\_id | The ID of VPC endpoint for DynamoDB |
| vpc\_endpoint\_dynamodb\_pl\_id | The prefix list for the DynamoDB VPC endpoint. |
| vpc\_endpoint\_s3\_id | The ID of VPC endpoint for S3 |
| vpc\_endpoint\_s3\_pl\_id | The prefix list for the S3 VPC endpoint. |
| vpc\_flowlog\_id | id of vpc flowlog |
| vpc\_flowlog\_role\_arn | vpc flow log arn |
| vpc\_id | The ID of the VPC |
| vpc\_instance\_tenancy | Tenancy of instances spin up within VPC |
| vpc\_main\_route\_table\_id | The ID of the main route table associated with this VPC |
| vpc\_secondary\_cidr\_blocks | List of secondary CIDR blocks of the VPC |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Tests

This module has been packaged with [awspec](https://github.com/k1LoW/awspec) tests through test kitchen. To run them:

1. Install [rvm](https://rvm.io/rvm/install) and the ruby version specified in the [Gemfile](https://github.com/terraform-aws-modules/terraform-aws-vpc/tree/master/Gemfile).
2. Install bundler and the gems from our Gemfile:
```
gem install bundler; bundle install
```
3. Test using `bundle exec kitchen test` from the root of the repo.


## License

Apache 2 Licensed. See LICENSE for full details.
