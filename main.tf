provider "aws" {
  region = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}


### AMI Ubuntu
# --------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

### VPC
# --------------------------------------------------

resource "aws_vpc" "webserver" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "webserver"
  }
}

### Subnet
# --------------------------------------------------

resource "aws_subnet" "subnet" {
  vpc_id                  = aws_vpc.webserver.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet"
  }
}

### Internet Gateway
# --------------------------------------------------

resource "aws_internet_gateway" "web" {
  vpc_id = aws_vpc.webserver.id

  tags = {
    Name = "web server"
  }
}


### Route Table
# --------------------------------------------------

resource "aws_route_table" "web" {
  vpc_id = aws_vpc.webserver.id
}

resource "aws_route" "web" {
  route_table_id         = aws_route_table.web.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.web.id
}

resource "aws_route_table_association" "web" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.web.id
}

### Security Group
# --------------------------------------------------

resource "aws_security_group" "kafka" {
  vpc_id = aws_vpc.webserver.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["52.51.244.9/32"]
  }

  # Kafka
  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # ZooKeeper client
  ingress {
    from_port   = 2181
    to_port     = 2181
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # ZooKeeper peer communication
  ingress {
    from_port   = 2888
    to_port     = 2888
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # ZooKeeper leader election
  ingress {
    from_port   = 3888
    to_port     = 3888
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

### SSH
# --------------------------------------------------

resource "aws_key_pair" "kafka" {
  key_name   = "kafka-key"
  public_key = file("/home/blent/.ssh/id_ed25519.pub")
}

### VM Kafka
# --------------------------------------------------

resource "aws_instance" "kafka" {
  count = 5
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.kafka.key_name
  subnet_id              = aws_subnet.subnet.id
  vpc_security_group_ids = [aws_security_group.kafka.id]

  tags = {
    Name = "kafka-broker-${count.index + 1}"
  }
}

### VM ZooKeeper
# --------------------------------------------------

resource "aws_instance" "zookeeper" {
  count = 3
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.kafka.key_name
  subnet_id              = aws_subnet.subnet.id
  vpc_security_group_ids = [aws_security_group.kafka.id]

  tags = {
    Name = "zookeeper-${count.index + 1}"
  }
}

### Outputs
# --------------------------------------------------

output "kafka_public_ip" {
  value = aws_instance.kafka[*].public_ip
}

output "kafka_private_ip" {
  value = aws_instance.kafka[*].private_ip
}

output "zookeeper_public_ip" {
  value = aws_instance.zookeeper[*].public_ip
}

output "zookeeper_private_ip" {
  value = aws_instance.zookeeper[*].private_ip
}