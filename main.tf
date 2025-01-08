data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

data "aws_vpc" "default" {
  default = true
}

module "web_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]


  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "8.0.1"

  name = "web"
  min_size                  = 1
  max_size                  = 2
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"

  vpc_zone_identifier       = module.web_vpc.public_subnets
  target_group_arns         = module.web_alb.target_group_arns
  security_group_ids        = [module.web_sg.security_group_id]

  image_id                  = data.aws_ami.app_ami.id
  instance_type             = var.instance_type
}

module "web_alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "web-alb"
  vpc_id  = module.web_vpc.vpc_id
  subnets = module.web_vpc.public_subnets
  security_groups = [module.web_sg.security_group_id]

  listeners = {
    listener_1 = {
      port     = 80
      protocol = "HTTP"
      target_group_index = 0
      forward = {
        target_group_key = "my_target"
      }
    }
  }

  target_groups = {
    my_target = {
      name_prefix      = "web-"
      protocol         = "HTTP"
      port             = 80
      target_type      = "instance"
    }
  }

  tags = {
    Environment = "dev"
  }
}

module "web_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"
  name = "web_new"

  vpc_id = module.web_vpc.vpc_id
  
  ingress_rules     = ["http-80-tcp", "https-443-tcp"]
  egress_rules      = ["all-all"]

  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_cidr_blocks = ["0.0.0.0/0"]

}