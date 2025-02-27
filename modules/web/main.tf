data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_filter.name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.ami_filter.owner]
}

data "aws_vpc" "default" {
  default = true
}

module "web_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.environment.name
  cidr = "${var.environment.network_prefix}.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["${var.environment.network_prefix}.101.0/24", "${var.environment.network_prefix}.102.0/24", "${var.environment.network_prefix}.103.0/24"]


  tags = {
    Terraform = "true"
    Environment = var.environment.name
  }
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "8.0.1"

  name = "web"
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"

  vpc_zone_identifier       = module.web_vpc.public_subnets
  security_groups           = [module.web_sg.security_group_id]

  image_id                  = data.aws_ami.app_ami.id
  instance_type             = var.instance_type
}

module "web_alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "web-alb"
  vpc_id  = module.web_vpc.vpc_id
  subnets = module.web_vpc.public_subnets
  security_groups = [module.web_sg.security_group_id]

  listeners = [
    {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = 0
      }
    }
  ]

  target_groups = [
    {
      name_prefix      = "${var.environment.name}-"
      protocol         = "HTTP"
      port             = 80
      target_type      = "instance"
      target_id        = var.instance_identification.instance_id
    }
  ]

  tags = {
    Environment = var.environment.name
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