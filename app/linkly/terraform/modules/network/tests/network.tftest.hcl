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
