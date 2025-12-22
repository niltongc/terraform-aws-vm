variable "user_name" {
  type    = string
  default = "ubuntu"
}

variable "private_key_path" {
  type        = string
  description = "path to ssh connection"
}
