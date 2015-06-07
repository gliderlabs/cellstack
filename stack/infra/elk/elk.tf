variable "secret_key" {}
variable "access_key" {}
variable "region" {}

variable "cell" {}

variable "name" {
  default = "elk"
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
  count = 1
  key_name = "${var.key_name}"
  subnet_id = "${element(split(\",\", terraform_remote_state.cell.output.subnet_ids), count.index)}"
  ami = "${var.ami}"
  instance_type = "${var.instance_type}"
  security_groups = [
    "${terraform_remote_state.cell.output.ssh_access}",
    "${terraform_remote_state.cell.output.shared_access}",
    "${terraform_remote_state.cell.output.http_access}"
  ]
  associate_public_ip_address = true
  tags {
    Name = "${terraform_remote_state.cell.output.name}-${var.name}${count.index+1}"
    Cell = "${terraform_remote_state.cell.output.name}"
    elk = ""
  }
  connection {
    user = "core"
    key_file = "${var.key_file}"
  }
  user_data = "${file(concat(path.module, \"/host.conf\"))}"
  provisioner "remote-exec" {
    inline = [
      "echo Ready!"
    ]
  }
}

output "public_ips" {
    value = "${join(\",\", aws_instance.host.*.public_ip)}"
}

output "url" {
  value = "http://${aws_instance.host.0.public_ip}"
}

output "name" {
  value = "${var.name}"
}
