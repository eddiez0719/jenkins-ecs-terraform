# create a new VPC jenkins_vpc

resource "aws_vpc" "jenkins_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    name = var.ecs_cluster_name
  }
}

# create an Internet Gateway jenkins_gateway

resource "aws_internet_gateway" "jenkins_gateway" {
  vpc_id = aws_vpc.jenkins_vpc.id
  tags = {
    name = var.ecs_cluster_name
  }
}

# create an external routing table

resource "aws_route_table" "external" {
  vpc_id = aws_vpc.jenkins_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jenkins_gateway.id
  }
}

# create a subnet

resource "aws_subnet" "jenkins_subnet" {
  vpc_id            = aws_vpc.jenkins_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.availability_zone

  tags = {
    Name = "jenkins_subnet"
  }
}

# create a route table association

resource "aws_route_table_association" "external-jenkins" {
  subnet_id      = aws_subnet.jenkins_subnet.id
  route_table_id = aws_route_table.external.id
}

# create security groups for jenkins ec2 instance

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins_sg"
  description = "Allow Https traffic"
  vpc_id      = aws_vpc.jenkins_vpc.id

  ingress {
    description = "Https to jenkins"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Http to jenkins"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH to jenkins"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["124.170.234.57/32"]
  }
  ingress {
    description = "JNLP"
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_secure_traffic"
  }
}

# create a new launch configuration
data "aws_ami" "amazon_linux_ecs" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}
data "template_file" "user_data" {
  template = "${file("${path.module}/user_data.tpl")}"
  vars = {
    cluster_name = var.ecs_cluster_name
  }
}

resource "aws_launch_configuration" "as_conf" {
  name_prefix                 = "jenkins-lc"
  image_id                    = data.aws_ami.amazon_linux_ecs.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  security_groups             = [aws_security_group.jenkins_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.iam_instance_profile.name
  user_data                   = data.template_file.user_data.rendered

  lifecycle {
    create_before_destroy = true
  }
}

# create an autoscaling group

resource "aws_autoscaling_group" "asg_jenkins" {
  name                      = "asg_${var.ecs_cluster_name}"
  max_size                  = var.max_size
  min_size                  = var.min_size
  health_check_grace_period = "300"
  health_check_type         = "EC2"
  desired_capacity          = var.desired_capacity
  launch_configuration      = aws_launch_configuration.as_conf.name
  vpc_zone_identifier       = [aws_subnet.jenkins_subnet.id]

  tag {
    key                 = "Name"
    value               = "${aws_ecs_cluster.jenkins_cluster.id}_asg"
    propagate_at_launch = true
  }
}

# create an ecs cluster jenkins

resource "aws_ecs_cluster" "jenkins_cluster" {
  name = var.ecs_cluster_name
}

# create a IAM role for task execution

#resource "aws_iam_role" "ecs_jenkins_role" {
# name = "ecs-jenkins-task-role"
# assume_role_policy = "${data.aws_iam_policy_document.ecs_task_role_assume.json}"
#}

#data "aws_iam_policy_document" "ecs_task_role_assume" {
# statement {
#  effect = "Allow"
#  actions = ["sts:AssumeRole"]
#  principals {
#    type = "Service"
#    identifiers = ["ecs-tasks.amazonaws.com"]
#  
#   }
#  }
#}

#resource "aws_iam_role_policy_attachment" "ecs-jenkins" {
#  role = "${aws_iam_role.ecs_jenkins_role.name}"
#  policy_arn = "${aws_iam_policy.ecs_jenkins_role_policy.arn}"
#}

#resource "aws_iam_policy" "ecs_jenkins_role_policy" {
#  name = "jenkins-agent-ecs-iam-role-policy"
#  policy = "${data.aws_iam_policy_document.ecs_jenkins_role.json}"
#}

#data "aws_iam_policy_document" "ecs_jenkins_role" {
#  statement {
#   sid = "AllowInstanceOperations"
#   effect = "Allow"
#   actions = [
#      "ec2:ModifyInstanceAttribute",
#      "ec2:RunInstances",
#      "ec2:StartInstances",
#      "ec2:StopInstances",
#      "ec2:RebootInstances",
#      "ec2:TerminateInstances",
#      "ec2:DescribeInstances",
#      "ec2:CreateTags",
#      "ec2:ResetInstanceAttribute"
#    ]
#    resources = [ "*" ]
#  }

#}

# create an ecs task definition

resource "aws_ecs_task_definition" "jenkins_task_definition" {
  family                = "jenkins_task_definition"
  container_definitions = <<EOF

 [
  
  {
   "name": "jenkins",
   "image": "${var.jenkins_image}",
   "privileged": true,
   "cpu": 1, 
   "memory": 512,
   "essential": true,
   "environment": [
   {
     "name": "JAVA_OPTS",
     "value": "${var.jenkins-java-opts}"

   }
   ],
   "portMappings": [
       { 
         "containerPort": 8080,
         "protocol": "tcp",
         "hostPort": 80
       },
       {
	 "containerPort": 50000,
         "protocol": "tcp",
         "hostPort": 50000
       }
      ],
   "mountPoints": [
        {
         "sourceVolume":"${var.source_volume}",
         "containerPath":"${var.container_path}"
        }
        ]
  }
 ]
 
EOF


  volume {
    name      = "jenkins-home"
    host_path = "/ecs/jenkins-home"
  }
}

# create an ecs service jenkins

resource "aws_ecs_service" "jenkins_service" {
  name            = "jenkins_service"
  cluster         = aws_ecs_cluster.jenkins_cluster.id
  task_definition = aws_ecs_task_definition.jenkins_task_definition.arn
  desired_count   = var.desired_capacity
  #depends_on = ["aws_autoscaling_group.asg_jenkins"]
}

# create an iam role for host

resource "aws_iam_role" "host_role_jenkins" {
  name               = "host_role_${var.ecs_cluster_name}"
  assume_role_policy = file("${path.module}/ecs_role.json")
}

resource "aws_iam_role_policy" "instance_role_policy_jenkins" {
  name   = "instance_role_policy_${var.ecs_cluster_name}"
  policy = file("${path.module}/ecs_instance_role_policy.json")
  role   = aws_iam_role.host_role_jenkins.id
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "iam_instance_profile_${var.ecs_cluster_name}"
  path = "/"
  role = aws_iam_role.host_role_jenkins.name
}

