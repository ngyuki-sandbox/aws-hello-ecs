////////////////////////////////////////////////////////////////////////////////
// VPC

data "aws_vpc" "default" {
  default = true
}

locals {
  // Data Source ‚¾‚Æ 1b ‚ªŠÜ‚Ü‚ê‚ÄŽ¸”s‚·‚é‚Ì‚Åƒxƒ^‚Å’è‹`
  availability_zones = [
    "ap-northeast-1a",
    "ap-northeast-1c",
  ]
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_security_group" "default" {
  name = "default"
}
