provider "aws"{
    profile = "default"
    region = "us-east-1"
}

resource "aws_vpc" "project_vpc" {
  cidr_block = "${var.vpc_cidr}"
}

resource "aws_subnet" "public_subnet" {
  vpc_id = "${aws_vpc.project_vpc.id}"
  cidr_block = "${var.subnet_cidr}"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"

  tags = {
    Name = "public_subnet"
  }
}

resource "aws_subnet" "public_subnet2" {
  vpc_id = "${aws_vpc.project_vpc.id}"
  cidr_block = "${var.subnet2_cidr}"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1c"

  tags = {
    Name = "public_subnet2"
  }
}

resource "aws_internet_gateway" "vpc_igw" {
  vpc_id = "${aws_vpc.project_vpc.id}"
}

resource "aws_security_group" "app_server_sg" {
  vpc_id = "${aws_vpc.project_vpc.id}"
  name = "http and ssh"
  description = "opens http and ssh ports"

  ingress  {
    from_port = "80"
    to_port = "80"
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
  } 

  ingress  {
    from_port = "22"
    to_port = "22"
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
  } 
}
resource "aws_security_group" "app_lb_sg" {
  vpc_id = "${aws_vpc.project_vpc.id}"
  name = "Load Balancer SG"
  description = "Security group for application load balancer"

  ingress {
    from_port = "80"
    to_port = "80"
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
  }
}

resource "aws_lb" "app_lb" {
  name = "application-load-balancer"
  subnets = ["${aws_subnet.public_subnet.id}","${aws_subnet.public_subnet2.id}"]
  security_groups = ["${aws_security_group.app_lb_sg.id}"]
  enable_cross_zone_load_balancing   = true

}

resource "aws_route_table" "route" {
  vpc_id = "${aws_vpc.project_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.vpc_igw.id}"
  }

  tags = {
    Name ="Route to the internet"
  }
}

resource "aws_route_table_association" "rt1" {
    subnet_id = "${aws_subnet.public_subnet.id}"
    route_table_id = "${aws_route_table.route.id}"
}

resource "aws_route_table_association" "rt2" {
    subnet_id = "${aws_subnet.public_subnet2.id}"
    route_table_id = "${aws_route_table.route.id}"
}

resource "aws_launch_configuration" "web" {
  name_prefix = "web-"
  image_id = "ami-0b0dcb5067f052a63" 
  instance_type = "t2.micro"
  key_name = "Assignment"
  security_groups = [ "${aws_security_group.app_server_sg.id}" ]
  associate_public_ip_address = true
  user_data = "${file("data.sh")}"

 lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "my-app-tg" {
  name = "my-app-tg"
  port = "80"
  protocol = "HTTP"
  vpc_id = "${aws_vpc.project_vpc.id}"

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
  }
}

resource "aws_autoscaling_group" "web" {
  name = "${aws_launch_configuration.web.name}-asg"
  min_size             = 1
  desired_capacity     = 1
  max_size             = 2
  
  health_check_type    = "ELB"
  target_group_arns = [aws_lb_target_group.my-app-tg.arn]
launch_configuration = "${aws_launch_configuration.web.name}"
enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]
metrics_granularity = "1Minute"
vpc_zone_identifier  = [
    "${aws_subnet.public_subnet.id}",
    "${aws_subnet.public_subnet2.id}"
  ]

  lifecycle {
    create_before_destroy = true
  }
tag {
    key                 = "Name"
    value               = "web"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "web_policy_up" {
  name = "web_policy_up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.web.name}"
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_up" {
  alarm_name = "web_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "70"
dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.web.name}"
  }
alarm_description = "This metric monitors EC2 instance CPU utilization"
  alarm_actions = [ "${aws_autoscaling_policy.web_policy_up.arn}" ]
}

resource "aws_autoscaling_policy" "web_policy_down" {
  name = "web_policy_down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.web.name}"
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_down" {
  alarm_name = "web_cpu_alarm_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "30"
dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.web.name}"
  }
alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = [ "${aws_autoscaling_policy.web_policy_down.arn}" ]
}

output "dns_name" {
  description = "The DNS name of the load balancer."
  value       = "${aws_lb.app_lb.dns_name}"
}