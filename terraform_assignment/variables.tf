# Defining Public Key
variable "public_key" {
  default = "Assignment.pub"
}
# Defining Private Key
variable "private_key" {
  default = "Assignment.pem"
}
# Definign Key Name for connection
variable "key_name" {
  default = "Assignment"
  description = "Name of AWS key pair"
}
# Defining CIDR Block for VPC
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}
# Defining CIDR Block for 1st Subnet
variable "subnet_cidr" {
  default = "10.0.1.0/24"
}
# Defining CIDR Block for 2nd Subnet
variable "subnet2_cidr" {
  default = "10.0.2.0/24"
}