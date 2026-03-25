locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    environment = var.environment
    service     = var.project
    owner       = var.owner
    cost_center = var.cost_center
    managed_by  = "terraform"
  }
}
