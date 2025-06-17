provider "aws" {
  region = local.region
}

# Provider cho cluster eks-kiali
provider "kubernetes" {
  alias                  = "kiali"
  host                   = module.eks-kiali.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks-kiali.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks-kiali.cluster_name]
  }
}

provider "kubectl" {
  host                   = module.eks-kiali.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks-kiali.cluster_certificate_authority_data)
  apply_retry_count      = 5
}

# Provider cho cluster eks-app
provider "kubernetes" {
  alias                  = "app"
  host                   = module.eks-app.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks-app.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks-app.cluster_name]
  }
}

# Helm provider cho eks-kiali
provider "helm" {
  alias = "kiali"
  kubernetes {
    host                   = module.eks-kiali.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks-kiali.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks-kiali.cluster_name]
    }
  }
}

# Helm provider cho eks-app
provider "helm" {
  alias = "app"
  kubernetes {
    host                   = module.eks-app.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks-app.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks-app.cluster_name]
    }
  }
}

data "aws_availability_zones" "available" {
  # Do not include local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name   = "thuan-eks"
  region = "ap-southeast-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  istio_chart_url     = "https://istio-release.storage.googleapis.com/charts"
  istio_chart_version = "1.26.1"
  # enable_cluster_encryption_config = false

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }
}

################################################################################
# Cluster
################################################################################

module "eks-kiali" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.11"

  cluster_name                   = "${local.name}-kiali"
  cluster_version                = "1.33"
  cluster_endpoint_public_access = true

  iam_role_arn = "arn:aws:iam::492804330065:role/thuan_devops_role"


  # Give the Terraform identity admin access to the cluster
  # which will allow resources to be deployed into the cluster
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    initial = {
      instance_types = ["t3.medium"]

      min_size      = 0
      max_size      = 10
      desired_size  = 3
      iam_role_name = "eksctl-thuan-istio-nodegroup-role"
    }
  }

  #  EKS K8s API cluster needs to be able to talk with the EKS worker nodes with port 15017/TCP and 15012/TCP which is used by Istio
  #  Istio in order to create sidecar needs to be able to communicate with webhook and for that network passage to EKS is needed.
  node_security_group_additional_rules = {
    ingress_15017 = {
      description                   = "Cluster API - Istio Webhook namespace.sidecar-injector.istio.io"
      protocol                      = "TCP"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_15012 = {
      description                   = "Cluster API to nodes ports/protocols"
      protocol                      = "TCP"
      from_port                     = 15012
      to_port                       = 15012
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }
  create_iam_role = false

  create_kms_key = false
  cluster_encryption_config = {}
  attach_cluster_encryption_policy = false

  create_cloudwatch_log_group = false
}

module "eks-app" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.11"

  cluster_name                   = "${local.name}-app"
  cluster_version                = "1.33"
  cluster_endpoint_public_access = true

  iam_role_arn = "arn:aws:iam::492804330065:role/thuan_devops_role"


  # Give the Terraform identity admin access to the cluster
  # which will allow resources to be deployed into the cluster
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    initial = {
      instance_types = ["t3.medium"]

      min_size      = 0
      max_size      = 10
      desired_size  = 3
      iam_role_name = "eksctl-thuan-istio-nodegroup-role"
    }
  }

  #  EKS K8s API cluster needs to be able to talk with the EKS worker nodes with port 15017/TCP and 15012/TCP which is used by Istio
  #  Istio in order to create sidecar needs to be able to communicate with webhook and for that network passage to EKS is needed.
  node_security_group_additional_rules = {
    ingress_15017 = {
      description                   = "Cluster API - Istio Webhook namespace.sidecar-injector.istio.io"
      protocol                      = "TCP"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_15012 = {
      description                   = "Cluster API to nodes ports/protocols"
      protocol                      = "TCP"
      from_port                     = 15012
      to_port                       = 15012
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }
  create_iam_role = false

  create_kms_key = false
  cluster_encryption_config = {}
  attach_cluster_encryption_policy = false

  create_cloudwatch_log_group = false
}

################################################################################
# EKS Blueprints Addons
################################################################################

data "http" "gateway_api_yaml" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml"
}

locals {
  raw_yaml = data.http.gateway_api_yaml.response_body

  docs = split("---", local.raw_yaml)

  manifests = [
    for doc in local.docs :
    yamldecode(trimspace(doc))
    if trimspace(doc) != "" && can(yamldecode(trimspace(doc)))
  ]
}

resource "kubectl_manifest" "gateway_api_crds" {
  for_each = {
    for m in local.manifests :
    "${m.kind}-${m.metadata.name}" => m
  }

  yaml_body = yamlencode(each.value)
}

resource "kubernetes_namespace_v1" "istio_system" {
  provider = kubernetes.kiali
  metadata {
    name = "istio-system"
  }
}

module "eks_blueprints_addons-kiali" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16"

  cluster_name      = module.eks-kiali.cluster_name
  cluster_endpoint  = module.eks-kiali.cluster_endpoint
  cluster_version   = module.eks-kiali.cluster_version
  oidc_provider_arn = module.eks-kiali.oidc_provider_arn

  # This is required to expose Istio Ingress Gateway
  providers = {
    kubernetes = kubernetes.kiali
    helm       = helm.kiali
  }
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    name                   = "alb-kiali"
    role_name              = "eksctl-thuan-istio-role"
    role_name_use_prefix   = false
    policy_name            = "eksctl-thuan-istio-policy"
    policy_name_use_prefix = false
    force_update           = true
    tags = {}
  }

  helm_releases = {
    istio-base = {
      chart         = "base"
      chart_version = local.istio_chart_version
      repository    = local.istio_chart_url
      name          = "istio-base"
      namespace     = kubernetes_namespace_v1.istio_system.metadata[0].name
      skip_crds     = true
    }

    istiod-ambient = {
      chart         = "istiod"
      chart_version = local.istio_chart_version
      repository    = local.istio_chart_url
      name          = "istiod"
      namespace     = kubernetes_namespace_v1.istio_system.metadata[0].name

      set = [
        {
          name  = "meshConfig.accessLogFile"
          value = "/dev/stdout"
        },
        {
          name  = "profile"
          value = "ambient"
        }
      ]
      wait         = true
      force_update = true
    }

    istio-cni = {
      chart         = "cni"
      chart_version = local.istio_chart_version
      repository    = local.istio_chart_url
      name          = "istio-cni"
      namespace     = kubernetes_namespace_v1.istio_system.metadata[0].name

      set = [
        {
          name  = "profile"
          value = "ambient"
        }
      ]
      wait = true
    }

    ztunnel = {
      chart         = "ztunnel"
      chart_version = local.istio_chart_version
      repository    = local.istio_chart_url
      name          = "ztunnel"
      namespace     = kubernetes_namespace_v1.istio_system.metadata[0].name

      wait = true
    }
  }
}
module "eks_blueprints_addons-app" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16"

  cluster_name      = module.eks-app.cluster_name
  cluster_endpoint  = module.eks-app.cluster_endpoint
  cluster_version   = module.eks-app.cluster_version
  oidc_provider_arn = module.eks-app.oidc_provider_arn

  # This is required to expose Istio Ingress Gateway
  providers = {
    kubernetes = kubernetes.app
    helm       = helm.app
  }
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    name                   = "alb-app"
    role_name              = "eksctl-thuan-istio-role-2"
    role_name_use_prefix   = false
    policy_name            = "eksctl-thuan-istio-policy-2"
    policy_name_use_prefix = false
    force_update           = true
  }
#   helm_releases = {
#     istio-base = {
#       chart         = "base"
#       chart_version = local.istio_chart_version
#       repository    = local.istio_chart_url
#       name          = "istio-base"
#       namespace     = kubernetes_namespace_v1.istio_system.metadata[0].name
#       skip_crds     = true
#     }

#     istiod-ambient = {
#       chart         = "istiod"
#       chart_version = local.istio_chart_version
#       repository    = local.istio_chart_url
#       name          = "istiod"
#       namespace     = kubernetes_namespace_v1.istio_system.metadata[0].name

#       set = [
#         {
#           name  = "meshConfig.accessLogFile"
#           value = "/dev/stdout"
#         },
#         {
#           name  = "profile"
#           value = "ambient"
#         }
#       ]
#       wait         = true
#       force_update = true
#     }

#     istio-cni = {
#       chart         = "cni"
#       chart_version = local.istio_chart_version
#       repository    = local.istio_chart_url
#       name          = "istio-cni"
#       namespace     = kubernetes_namespace_v1.istio_system.metadata[0].name

#       set = [
#         {
#           name  = "profile"
#           value = "ambient"
#         }
#       ]
#       wait = true
#     }

#     ztunnel = {
#       chart         = "ztunnel"
#       chart_version = local.istio_chart_version
#       repository    = local.istio_chart_url
#       name          = "ztunnel"
#       namespace     = kubernetes_namespace_v1.istio_system.metadata[0].name

#       wait = true
#     }
#   }
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}
