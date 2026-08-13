# infra/variables.tf

variable "admin_ip" {
  type        = string
  description = "Public IP of the execution runner (Pipeline) for NSG whitelisting."
}

variable "admin_ssh_public_key" {
  type        = string
  description = "Public SSH key dynamically injected from the CI/CD pipeline memory."
}