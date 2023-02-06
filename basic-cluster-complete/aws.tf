resource "random_id" "vpc_display_id" {
    byte_length = 4
}
# ------------------------------------------------------
# VPC
# ------------------------------------------------------
resource "aws_vpc" "main" { 
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "simple-basic-demo-vpc-${random_id.vpc_display_id.hex}"
        Owner = "${local.owner}"
    }
}
# ------------------------------------------------------
# SUBNETS
# ------------------------------------------------------
resource "aws_subnet" "public_subnets" {
    count = 3
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.${count.index+1}.0/24"
    map_public_ip_on_launch = true
    tags = {
        Name = "simple-basic-demo-public-subnet-${count.index}-${random_id.vpc_display_id.hex}"
        Owner = "${local.owner}"
    }
}
# ------------------------------------------------------
# IGW
# ------------------------------------------------------
resource "aws_internet_gateway" "igw" { 
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "simple-basic-demo-igw-${random_id.vpc_display_id.hex}"
        Owner = "${local.owner}"
    }
}
# ------------------------------------------------------
# ROUTE TABLE
# ------------------------------------------------------
resource "aws_route_table" "route_table" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Name = "simple-basic-demo-route-table-${random_id.vpc_display_id.hex}"
        Owner = "${local.owner}"
    }
}
resource "aws_route_table_association" "subnet_associations" {
    count = 3
    subnet_id = aws_subnet.public_subnets[count.index].id
    route_table_id = aws_route_table.route_table.id
}
# ------------------------------------------------------
# SECURITY GROUP
# ------------------------------------------------------
resource "aws_security_group" "postgres_sg" {
    name = "postgres_security_group_${random_id.vpc_display_id.hex}"
    description = "SG for postgres on simple basic demo"
    vpc_id = aws_vpc.main.id
    egress {
        description = "Allow all outbound."
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
    }
    ingress {
        description = "Postgres"
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }
    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }
    tags = {
        Name = "simple-basic-demo-postgres-sg-${random_id.vpc_display_id.hex}"
        Owner = "${local.owner}"
    }
}
# ------------------------------------------------------
# CLOUDINIT
# ------------------------------------------------------
resource "random_id" "pg_id" {
    byte_length = 4
}
data "template_cloudinit_config" "pg_bootstrap" {
    base64_encode = true
    part {
        content_type = "text/x-shellscript"
        content = "${file("scripts/pg_init.sh")}"
    }
}

resource "aws_instance" "postgres_db_instance" {
    ami = "${local.ami}"
    instance_type = "t3.small"
    subnet_id = aws_subnet.public_subnets[0].id
    vpc_security_group_ids = ["${aws_security_group.postgres_sg.id}"]
    user_data = "${data.template_cloudinit_config.pg_bootstrap.rendered}"
    associate_public_ip_address = true
    key_name = "${local.key}"

    root_block_device {
        volume_size = 20
    }

    tags = {
        Name = "simple-basic-demo-postgres-customers-instance-${random_id.pg_id.hex}"
        Owner = "${local.owner}"
    }
}
# ------------------------------------------------------
# PG DB EC2 EIP
# ------------------------------------------------------
resource "aws_eip" "postgres_db_eip" {
    vpc = true
    instance = aws_instance.postgres_db_instance.id
    tags = {
        Name = "simple-basic-demo-postgres-customers-eip-${random_id.pg_id.hex}"
        Owner = "${local.owner}"
    }
}

output "PublicIP" {
  value = aws_eip.postgres_db_eip.public_ip
}