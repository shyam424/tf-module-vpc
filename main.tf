resource "aws_vpc" "main" {
  cidr_block = var.cidr
}

module "subnets" {
  source = "./subnets"
  for_each = var.subnets
  subnets = each.value
  vpc_id = aws_vpc.main.id
}


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

output "subnets" {
  value = module.subnets
}


#outputs.tf which was created in the subnets module will be pulled here and this will be sent to the root module which is roboshop-vpc(main.tfc).
#thisis called data transmitting
