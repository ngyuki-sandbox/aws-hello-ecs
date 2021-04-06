
module "vpc" {
  source = "../../modules/defaultvpc"
  name   = var.name
}

module "elb" {
  source             = "../../modules/elb"
  name               = var.name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.subnet_ids
  security_group_ids = [module.vpc.security_group_id]
}

module "ecs" {
  source             = "../../modules/ecs"
  name               = var.name
  subnet_ids         = module.vpc.subnet_ids
  security_group_ids = [module.vpc.security_group_id]
  target_group_arn   = module.elb.target_group_arn

  // TargetGroup が LB にアタッチされたあとでなければならない
  depends_on = [module.elb]
}
