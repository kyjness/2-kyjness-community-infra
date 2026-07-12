variable "project_name" {
  type    = string
  default = "puppytalk"
}

variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.1.0.0/16"
  description = "EKS 전용 VPC 대역 (terraform/ ECS VPC 10.0.0.0/16과 분리)"
}

variable "eks_cluster_version" {
  type    = string
  default = "1.30"
}

variable "eks_node_min_size" {
  type    = number
  default = 2
}

variable "eks_node_max_size" {
  type    = number
  default = 5
}

variable "eks_node_desired_size" {
  type    = number
  default = 2
}
