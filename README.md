# AWS Network Firewall — Native Transit Gateway Integration

Terraform implementation of AWS Network Firewall with native Transit Gateway attachment (GA in eu-west-1). No inspection VPC required.

## Architecture

```
Workload VPC A (10.1.0.0/16)          Workload VPC B (10.2.0.0/16)
  ├── workload-a-instance-1 (AZ-a)      ├── workload-b-instance-1 (AZ-a)
  ├── workload-a-instance-2 (AZ-b)      ├── workload-b-instance-2 (AZ-b)
  └── TGW attachment subnets            └── TGW attachment subnets
              │                                      │
              └──────────── Transit Gateway ─────────┘
                                  │
                        AWS Network Firewall
                       (native TGW attachment)
                                  │
                         Egress VPC (10.0.0.0/16)
                           ├── NAT GW AZ-a
                           ├── NAT GW AZ-b
                           └── Internet Gateway
```

### Traffic Flows

- **East-West** (VPC A ↔ VPC B): TGW → NW-FW inspection → TGW → destination
- **North-South** (workload → internet): TGW → NW-FW inspection → Egress VPC → NAT GW → IGW

### TGW Route Tables

| Route Table | Associated To | Routes |
|---|---|---|
| spoke-rt | Workload VPC A & B attachments | 0.0.0.0/0, 10.1.0.0/16, 10.2.0.0/16 → NW-FW |
| firewall-rt | NW-FW attachment | 10.1.0.0/16 → VPC A, 10.2.0.0/16 → VPC B, 0.0.0.0/0 → Egress |
| egress-rt | Egress VPC attachment | 10.1.0.0/16, 10.2.0.0/16 → NW-FW |

## Module Structure

```
├── main.tf                   # Root — wires all modules
├── variables.tf
├── outputs.tf
├── data.tf                   # Region, account, and partition data sources
├── versions.tf               # Terraform >= 1.3, AWS provider ~> 6.0
├── terraform.tfvars
├── iam/                      # IAM role, SSM + S3 + CW policies, instance profile
└── modules/
    ├── firewall/             # NW-FW policy + stateless/stateful rule groups
    ├── tgw/                  # Transit Gateway, VPC attachments, NW-FW native attachment, route tables
    ├── workload_vpc/         # VPC, workload subnets (multi-AZ), TGW subnets, SG, SSM endpoints
    ├── egress_vpc/           # VPC, IGW, dual NAT GWs (multi-AZ), TGW subnets, route tables
    └── compute/              # 2 EC2 instances per workload VPC (one per AZ)
```

## Resources Created

| Resource | Count |
|---|---|
| VPCs | 3 (workload-a, workload-b, egress) |
| Transit Gateway | 1 |
| AWS Network Firewall | 1 (TGW-attached, no VPC) |
| TGW Route Tables | 3 |
| EC2 Instances | 4 (2 per workload VPC) |
| NAT Gateways | 2 (one per AZ in egress VPC) |
| SSM VPC Endpoints | 6 (ssm, ssmmessages, ec2messages × 2 VPCs) |

## Firewall Rules

- **Stateless**: forward all traffic to stateful engine
- **Stateful PASS**: ICMP (any direction), TCP 443 and TCP 80 from `10.0.0.0/8`
- **Default**: drop all other traffic

## Prerequisites

- AWS CLI configured (default profile, or set `aws_profile` in `terraform.tfvars`)
- Terraform >= 1.3
- AWS provider ~> 6.0
- Region: `eu-west-1` (Ireland) — NW-FW native TGW integration is GA here

## Deploy

```bash
terraform init
terraform plan
terraform apply
```

## Test Connectivity

Connect via SSM Session Manager (no SSH required):

```bash
# East-west ping (from instance in VPC A to instance in VPC B)
ping <workload-b-private-ip>

# North-south
curl -I https://example.com
```

## Clean Up

```bash
terraform destroy
```

## References

- [AWS Network Firewall native Transit Gateway support](https://aws.amazon.com/about-aws/whats-new/2025/06/aws-network-firewall-transit-gateway-native-integration/)
- [Route traffic through a TGW network function attachment](https://docs.aws.amazon.com/vpc/latest/tgw/route-traffic-nf-attachment.html)
- [AWS Network Firewall Developer Guide](https://docs.aws.amazon.com/network-firewall/latest/developerguide/what-is-aws-network-firewall.html)
