
module "vpc" {
  source = "../../modules/defaultvpc"
  name   = var.name
}

module "ecs" {
  source             = "./ecs"
  name               = var.name
  subnet_ids         = module.vpc.subnet_ids
  security_group_ids = [module.vpc.security_group_id]
}
