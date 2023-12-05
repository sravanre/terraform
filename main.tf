resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags = {
    Name = "main"
  }
}



# Create an Internet Gateway and set the tag
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "Sravan-IGW"
  }
}

# Create an Elastic IP for the NAT gateway
resource "aws_eip" "main_eip" {}


# Create a public subnet in us-east-1a with the "Name" tag and resource name
resource "aws_subnet" "public_subnet_1a" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public subnet 1a"
  }
}

resource "aws_subnet" "private_subnet_1c" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = false
  tags = {
    Name = "Private subnet 1c"
  }
}



resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
  tags = {
    Name = "publicRouteTable"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.main_nat_gw.id
  }
  tags = {
    Name = "privateRouteTable"
  }
}

resource "aws_route_table_association" "route_table_association" {
  subnet_id      = aws_subnet.public_subnet_1a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "route_table_association_private" {
  subnet_id      = aws_subnet.private_subnet_1c.id
  route_table_id = aws_route_table.private_rt.id
}

# Create a NAT gateway in the public subnet and set the tag
resource "aws_nat_gateway" "main_nat_gw" {
  allocation_id = aws_eip.main_eip.id
  subnet_id     = aws_subnet.public_subnet_1a.id
  tags = {
    Name = "Sravan-NAT-GW"
  }
}



data "aws_ami" "latest_ubuntu_22" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["099720109477"] # Canonical account ID for official Ubuntu AMIs
}

resource "aws_key_pair" "my_key" {
  key_name   = "aws-ec2-demo"  # Replace with your key name
  public_key = file("aws-ec2-demo.pub")  # Replace with your public key file path
}

# Create a security group allowing SSH from 0.0.0.0/0 and egress for internet access
resource "aws_security_group" "ec2-instance-sg" {
  name        = "ec2-instance-sg"
  description = "Security group for EC2 instance SSH access and internet egress"
  vpc_id      = aws_vpc.main_vpc.id

  # Ingress rule for SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip_address}"]   # so that only i can access from my network, 
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip_address}"]   # so that only i can access from my network, 
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip_address}"]   # so that only i can access from my network, 
  }

  # Egress rule for internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an EC2 instance in the public subnet with user data
resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.latest_ubuntu_22.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.public_subnet_1a.id
  key_name                    = aws_key_pair.my_key.key_name # Replace with your SSH key pair name
  associate_public_ip_address = true
  security_groups = [ "${aws_security_group.ec2-instance-sg.id}" ]
  user_data                   = <<-EOF
    #!/bin/bash
    sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt-get update 
    sudo apt install openjdk-11-jre -y 
    sudo apt-get install jenkins -y 
    sudo systemctl start jenkins.service
    sudo systemctl enable jenkins.service
    sudo ufw allow 8080
    sudo apt install apache2 -y
    sudo systemctl start apache2 
    sudo systemctl enable apache2

  EOF

  tags = {
    Name = "web-server-1"
  }
}

resource "aws_security_group" "ec2-instance-sg2" {
  name        = "ec2-instance-sg2"
  description = "Security group for EC2 instance SSH access and internet egress"
  vpc_id      = aws_vpc.main_vpc.id

  # Ingress rule for SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2-instance-sg.id]
       # so that only i can access from my network, 
  }

  # Egress rule for internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an EC2 instance in the private subnet with user data
resource "aws_instance" "web_server-2" {
  ami                         = data.aws_ami.latest_ubuntu_22.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private_subnet_1c.id
  key_name                    = aws_key_pair.my_key.key_name # Replace with your SSH key pair name
  associate_public_ip_address = false
  security_groups = [ "${aws_security_group.ec2-instance-sg2.id}" ]
  user_data                   = <<-EOF
    #!/bin/bash
    echo "Hello from the user data script from the server private for db" > /home/ubuntu/apache_installation.txt
    # Add your Apache installation script here
  EOF

  tags = {
    Name = "web-server-2"
  }
}


