# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "new_vpc" {

  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "new_vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.new_vpc.id
}

resource "aws_subnet" "new_subnet" {
  vpc_id                  = aws_vpc.new_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "new_subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.new_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.new_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "subnet_security_group" {
  vpc_id = aws_vpc.new_vpc.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "default" {
  key_name   = "aws_gen"
  public_key = file("~/.ssh/aws_gen.pub")
}

data "archive_file" "roles" {
  type        = "zip"
  source_dir  = "${path.module}/ansible/roles"
  output_path = "${path.module}/ansible/roles.zip"
}


resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.new_subnet.id
  vpc_security_group_ids = [aws_security_group.subnet_security_group.id]
  key_name               = aws_key_pair.default.key_name

  user_data = templatefile("${path.module}/scripts/setup_env.tpl", {
    user_name     = var.user_name
    playbook_data = file("${path.module}/ansible/playbook.yml")
    roles_archive = filebase64(data.archive_file.roles.output_path)
  })


  tags = {
    Name = "VmTest"
  }
}

output "public_ip" {
  value = aws_instance.web.public_ip
}