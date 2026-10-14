mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["eu-central-1a", "eu-central-1b", "eu-central-1c"] }
  }
}

variables {
  name = "linkly-course"
}

run "public_subnets_in_separate_zones" {
  command = plan
  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "expected 2 public subnets by default"
  }
  assert {
    condition     = aws_subnet.public[0].availability_zone != aws_subnet.public[1].availability_zone
    error_message = "the subnets must be in different Availability Zones"
  }
  assert {
    condition     = [for s in aws_subnet.public : s.cidr_block] == ["10.0.1.0/24", "10.0.2.0/24"]
    error_message = "unexpected subnet ranges"
  }
  assert {
    condition     = alltrue([for s in aws_subnet.public : s.map_public_ip_on_launch])
    error_message = "public subnets must give instances a public IP"
  }
}

run "routes_everything_else_to_the_internet_gateway" {
  command = apply
  assert {
    condition     = one(aws_route_table.public.route).cidr_block == "0.0.0.0/0" && one(aws_route_table.public.route).gateway_id == aws_internet_gateway.this.id
    error_message = "the public route table must send 0.0.0.0/0 to the internet gateway"
  }
  assert {
    condition     = length(aws_route_table_association.public) == 2
    error_message = "both subnets must use the public route table"
  }
}

run "no_private_subnets_unless_asked" {
  command = plan
  assert {
    condition     = length(aws_subnet.private) == 0
    error_message = "Module 7's environment has no private subnets"
  }
}

run "private_subnets_have_no_way_out" {
  command = apply
  variables {
    private_subnets    = true
    public_subnet_tags = { "kubernetes.io/role/elb" = "1" }
  }
  assert {
    condition     = length(aws_subnet.private) == 2 && aws_subnet.private[0].availability_zone != aws_subnet.private[1].availability_zone
    error_message = "two private subnets in different zones (RDS needs two)"
  }
  assert {
    condition     = [for s in aws_subnet.private : s.cidr_block] == ["10.0.101.0/24", "10.0.102.0/24"]
    error_message = "unexpected private subnet ranges"
  }
  assert {
    condition     = alltrue([for s in aws_subnet.private : !s.map_public_ip_on_launch])
    error_message = "private subnets must not hand out public IPs"
  }
  assert {
    condition     = length(aws_route_table.private[0].route) == 0
    error_message = "private subnets must have no route to the internet"
  }
  assert {
    condition     = alltrue([for s in aws_subnet.public : s.tags["kubernetes.io/role/elb"] == "1"])
    error_message = "public subnets must carry the tag Kubernetes uses to place internet load balancers"
  }
  assert {
    condition     = length(output.private_subnet_ids) == 2
    error_message = "the private subnet IDs must be an output"
  }
}
