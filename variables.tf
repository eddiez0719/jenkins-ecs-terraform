variable "jenkins-java-opts" {
 default = "-Xmx4096m"
}

variable "ecs_cluster_name" {
  description = "The name of the AWS ECS cluster"
  default = "jenkins_cluster"
}

variable "availability_zone" {
 description = "AWS availability zone"
 default = "ap-southeast-2a"
}

variable "jenkins_image" {
 description = "version of a jenkins image"
 default = "jenkins:2.3"
}

variable "container_port"{
 description = "port of a container"
 default = "8080"
}

variable "host_port"{
 description = "port of a host"
 default = "80"
}

variable "lb_port"{
 description = "port of a load balancer"
 default = "50000"
}

variable "lb_port_host"{
 description = "port of a container"
 default = "50000"
}

variable "source_volume" {
 description = "source volume"
 default = "jenkins-home"
}

variable "container_path" {
 description = "container path"
 default = "/var/jenkins-home"
}

variable "image_id"{
 description = "image id"
 default = "ami-04f77aa5970939148"
}

variable "instance_type"{
 description = "instance type"
 default = "t2.micro"
}

variable "max_size" {
 description = "max ec2 numbers"
 default = "3"
}

variable "min_size" {
 default = "1"
}

variable "desired_capacity" {
 default = "1"
}

variable "ports" {

 default = {
   http = 80
   jnlp = 50000
 }
}

