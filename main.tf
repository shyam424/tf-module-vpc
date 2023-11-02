resource "aws_vpc" "main" {
  cidr_block = var.cidr
  tags = merge (local.tags, {Name = "${var.env}-vpc"}}
}

module "subnets" {
  source = "./subnets"
  for_each = var.subnets
  subnets = each.value
  vpc_id = aws_vpc.main.id
  tags = local.tags
  env = var.env
}


resource "aws_internet_gateway" "igw" {    #internet gateway creation
  vpc_id = aws_vpc.main.id
  tags = merge (local.tags, {Name = "${var.env}-igw"}}
}

resource "aws_route" "igw" {
  for_each                  = lookup (lookup(module.subnets, "public", null), "route_table_ids" , null)
  route_table_id            = each.value["id"]
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.igw.id
}

# adding internet gate way to the public subnets only (we have 2 public subnets)

resource "aws_eip" "ngw"  {
  count = length(local.public_subnet_ids)
  domain = "vpc"
}

# nat gate ways will have elastic IPs which are creating above

resource "aws_nat_gateway" "ngw" {
  #for_each                  = lookup (lookup(module.subnets, "public", null), "subnet_ids" , null)
  count                     = length(local.public_subnet_ids)
  allocation_id             = element(aws_eip.ngw.*.id, count.index)
  subnet_id                 = element(local.public_subnet_ids, count.index)
  tags = merge (local.tags, {Name = "${var.env}-ngw"}}
}

#Nat gateways are creating and pulling the elastic IPs from the above


resource "aws_route" "ngw" {
  count                     = length(local.private_route_table_ids)
  route_table_id            = element(local.private_route_table_ids, count.index)
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id                = element(aws_nat_gateway.ngw.*.id, count.index)
}

#route for ngw

resource "aws_vpc_peering_connection"  "peering" {
  peer_vpc_id   = aws_vpc.main.id
  vpc_id        = var.default_vpc_id
  auto_accept   = true
  tags = merge (local.tags, {Name = "${var.env}-peer"}}
}
#peering connection

resource "aws_route" "peering" {
  count                     = length(local.private_route_table_ids)
  route_table_id            = element(local.private_route_table_ids, count.index)
  destination_cidr_block    = var.default_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
}

#route table peering connection


resource "aws_route" "default-vpc-peer-entry" {
  route_table_id            = var.default_vpc_route_table_id
  destination_cidr_block    = var.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
}

#outputs.tf which was created in the subnets module will be pulled here and this will be sent to the root module which is roboshop-vpc(main.tfc).
#thisis called data transmitting
#Creating security group below

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
      }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}
#network connection is completed here

#now the target is -if you create any instance then it should have only private IP address and only workstation will be able to access that
