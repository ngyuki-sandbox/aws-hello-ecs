
module "vpc" {
  source = "../../modules/vpc"
  name   = var.name
}

module "elb" {
  source             = "../../modules/elb"
  name               = var.name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [module.vpc.public_security_group_id]
}

module "ecs" {
  source             = "../../modules/ecs"
  name               = var.name
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.private_security_group_id]
  assign_public_ip   = false
  target_group_arn   = module.elb.target_group_arn

  // TargetGroup が LB にアタッチされたあとでなければならない
  depends_on = [module.elb]
}
