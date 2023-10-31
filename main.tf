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

resource "aws_nat_gateway" "example" {
  for_each                  = lookup (lookup(module.subnets, "public", null), "subnet_ids" , null)
  allocation_id             = lookup(aws_eip.ngw, each.value["id"], null)
  subnet_id                 = each.value["id"]
}

#Nat gateways are creating and pulling the elastic IPs from the above

output "subnets" {
  value = module.subnets
}


#outputs.tf which was created in the subnets module will be pulled here and this will be sent to the root module which is roboshop-vpc(main.tfc).
#thisis called data transmitting
