variable "secret_key" {}
variable "access_key" {}

variable "name" {}
variable "region" {
  default = "us-east-1"
}
variable "zones" {
  default = "a,b,c"
}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

resource "aws_vpc" "cell" {
  cidr_block = "172.100.0.0/16"
  enable_dns_hostnames = true
  tags {
    Name = "${var.name}"
  }
}

resource "aws_subnet" "zone" {
  count = 3
  vpc_id = "${aws_vpc.cell.id}"
  availability_zone = "${var.region}${element(split(\",\", var.zones), count.index)}"
  cidr_block = "172.100.${count.index * 4}.0/22"
  map_public_ip_on_launch = true
  tags {
    Name = "${var.name}-zone${count.index+1}"
    Cell = "${var.name}"
  }
}

resource "aws_route_table" "routes" {
	vpc_id = "${aws_vpc.cell.id}"

	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = "${aws_internet_gateway.gateway.id}"
	}
  tags {
    Name = "${var.name}-routes"
  }
}

resource "aws_route_table_association" "route" {
  count = 3
  subnet_id = "${element(aws_subnet.zone.*.id, count.index)}"
  route_table_id = "${aws_route_table.routes.id}"
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = "${aws_vpc.cell.id}"
  tags {
    Name = "${var.name}-gateway"
    Cell = "${var.name}"
  }
}

resource "aws_security_group" "shared" {
  description = "${var.name} shared"
  name = "${var.name}-shared"
  vpc_id = "${aws_vpc.cell.id}"

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    self = true
  }

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "udp"
    self = true
  }

  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssh" {
  description = "${var.name} ssh"
  name = "${var.name}-ssh"
  vpc_id = "${aws_vpc.cell.id}"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "http" {
  description = "${var.name} http"
  name = "${var.name}-http"
  vpc_id = "${aws_vpc.cell.id}"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "https" {
  description = "${var.name} https"
  name = "${var.name}-https"
  vpc_id = "${aws_vpc.cell.id}"

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


output "http_access" {
  value = "${aws_security_group.http.id}"
}

output "https_access" {
  value = "${aws_security_group.https.id}"
}

output "ssh_access" {
  value = "${aws_security_group.ssh.id}"
}

output "shared_access" {
  value = "${aws_security_group.shared.id}"
}

output "vpc_id" {
  value = "${aws_vpc.cell.id}"
}

output "region" {
  value = "${var.region}"
}

output "subnet_ids" {
  value = "${join(\",\", aws_subnet.zone.*.id)}"
}

output "name" {
  value = "${var.name}"
}

output "zone_count" {
  value = "3"
}
