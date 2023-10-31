resource "aws_vpc" "main" {
  cidr_block = var.cidr
}

module "subnets" {
  source = "./subnets"
  for_each = var.subnets
  subnets = each.value
  vpc_id = aws_vpc.main.id
}


resource "aws_internet_gateway" "igw" {    #internet gateway creation
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

resource "aws_route" "igw" {
  for_each                  = lookup (lookup(module.subnets, "public", null), "route_table_ids" , null)
  route_table_id            = each.value["id"]
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.igw.id
}

# adding internet gate way to the public subnets only (we have 2 public subnets)

resource "aws_eip" "ngw"  {
  for_each = lookup(lookup(module.subnets, "public", null), "subnet_ids", null)
  domain = "vpc"
}

# nat gate ways will have elastic IPs which are creating above

resource "aws_nat_gateway" "ngw" {
  #for_each                  = lookup (lookup(module.subnets, "public", null), "subnet_ids" , null)
  count                     = local.public_subnet_ids
  allocation_id             = element(aws_eip.ngw.*.id, count.index)
  subnet_id                 = element(local.public_subnet_ids, count.index)
}

#Nat gateways are creating and pulling the elastic IPs from the above


resource "aws_route" "ngw" {
  count                     = local.private_route_table_ids
  route_table_id            = element(local.private_route_table_ids, count.index)
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = element(aws_nat_gateway.ngw.*.id, count.index)
}

output "subnets" {
  value = module.subnets
}


#outputs.tf which was created in the subnets module will be pulled here and this will be sent to the root module which is roboshop-vpc(main.tfc).
#thisis called data transmitting
