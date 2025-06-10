# Istio

## Enable OIDC

```bash
eksctl utils associate-iam-oidc-provider --cluster thuan-eks --approve --region ap-southeast-1
aws eks update-kubeconfig --region ap-southeast-1 --name thuan-eks
```

## Clone appplication project

```bash
git clone --depth 1 --branch v0 https://github.com/GoogleCloudPlatform/microservices-demo.git
cd microservices-demo/
```

## Reference

<https://github.com/GoogleCloudPlatform/microservices-demo/blob/main/README.md>
