terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"
  profile = "kolia"
}

resource "aws_instance" "master" {
  ami           = "ami-0862be96e41dcbf74" // Amazon Ubuntu Server 24.04
  instance_type = "t3.micro"
  key_name      = "kolia"
  tags = {
    Name = "master"
  }

  provisioner "file" {
    source      = "kubeadm-k8s1.30.sh"
    destination = "/tmp/setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup.sh",
      "/tmp/setup.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/kolia.pem")
      host        = self.public_ip
    }
  }
}

resource "aws_instance" "worker-1" {
  ami           = "ami-0862be96e41dcbf74" // Amazon Ubuntu Server 24.04
  instance_type = "t3.micro"
  key_name      = "kolia"
  tags = {
    Name = "worker"
  }
}

output "public_ip_master" {
  value = aws_instance.master.public_ip
}

# output "public_ip_worker-1" {
#   value = aws_instance.worker-1.public_ip
# }
