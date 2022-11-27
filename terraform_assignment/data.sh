#!/bin/bash
sudo su root
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install -y epel-release
yum update -y
yum install nginx -y
systemctl start nginx
systemctl enable nginx
touch  /usr/share/nginx/html/index.html
echo "if you are able to see this, that means The Terraform Script has successfully executed and outputed the dns name of load balancer." > /usr/share/nginx/html/index.html
sudo su ec2-user
systemctl status nginx