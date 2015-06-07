variable "secret_key" {}
variable "access_key" {}
variable "region" {}

variable "cell" {}
variable "zone_count" {
  default = 3
}

variable "name" {
  default = "consul"
}

variable "key_name" {}
variable "key_file" {}

variable "ami" {}

variable "instance_type" {
  default = "m3.medium"
}

resource "terraform_remote_state" "cell" {
    backend = "atlas"
    config {
        name = "${var.cell}"
    }
}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

resource "aws_instance" "host" {
  count = "${var.zone_count}"
  key_name = "${var.key_name}"
  subnet_id = "${element(split(\",\", terraform_remote_state.cell.output.subnet_ids), count.index)}"
  ami = "${var.ami}"
  instance_type = "${var.instance_type}"
  security_groups = [
    "${terraform_remote_state.cell.output.shared_access}",
    "${terraform_remote_state.cell.output.ssh_access}",
    "${aws_security_group.consul.id}"
  ]
  associate_public_ip_address = true
  tags {
    Name = "${terraform_remote_state.cell.output.name}-${var.name}${count.index+1}"
    Cell = "${terraform_remote_state.cell.output.name}"
    consul = ""
  }
  connection {
    user = "core"
    key_file = "${var.key_file}"
  }
  user_data = "${file(concat(path.module, \"/host.conf\"))}"
}

resource "aws_security_group" "consul" {
  description = "Consul web traffic"
  name = "${var.name}"
  vpc_id = "${terraform_remote_state.cell.output.vpc_id}"

  ingress {
    from_port = 8500
    to_port = 8500
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

output "public_ips" {
    value = "${join(\",\", aws_instance.host.*.public_ip)}"
}

output "url" {
  value = "http://${aws_instance.host.0.public_ip}:8500"
}

output "name" {
  value = "${var.name}"
}
