# AWS Network Firewall — Native Transit Gateway Integration

Terraform implementation of AWS Network Firewall with native Transit Gateway attachment (GA in `eu-west-1`). No inspection VPC required — the firewall attaches directly to the TGW.

Includes a dedicated **ALB VPC** with an internet-facing Application Load Balancer. Placing the ALB in a separate VPC forces all ALB ↔ EC2 traffic to cross the TGW, ensuring NW-FW inspects every request in both directions.

---

## Architecture

```
                        Internet
                            │
                    IGW (ALB VPC)
                            │
              ALB VPC (10.3.0.0/16)
              ├── Public subnets /27 × 2 (ALB nodes)
              └── TGW attachment subnets /28 × 2
                            │
              ┌─────────────┴──────────────┐
              │         Transit Gateway     │
              └─────────────┬──────────────┘
                            │
                  AWS Network Firewall
                 (native TGW attachment)
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
Workload VPC A       Workload VPC B      Egress VPC
(10.1.0.0/16)        (10.2.0.0/16)      (10.0.0.0/16)
 ├── EC2 AZ-a         ├── EC2 AZ-a        ├── NAT GW AZ-a (EIP)
 ├── EC2 AZ-b         └── EC2 AZ-b        ├── NAT GW AZ-b (EIP)
 └── TGW /28 × 2      └── TGW /28 × 2    └── Internet Gateway
```

### Traffic Flows

- **ALB → EC2** (inbound): Internet → IGW (ALB VPC) → ALB → TGW spoke-rt → NW-FW → TGW firewall-rt → EC2 (VPC A)
- **EC2 → ALB** (response): EC2 (VPC A) → TGW spoke-rt → NW-FW → TGW firewall-rt → ALB VPC → ALB → Internet
- **East-West** (VPC A ↔ VPC B): Workload → TGW spoke-rt → NW-FW → TGW firewall-rt → destination VPC
- **North-South** (workload → internet): Workload → TGW spoke-rt → NW-FW → TGW firewall-rt → Egress VPC → NAT GW → IGW

### TGW Route Tables

| Route Table | Associated Attachment(s) | Routes |
|---|---|---|
| `spoke-rt` | Workload VPC A, Workload VPC B, ALB VPC | `0.0.0.0/0`, `10.1.0.0/16`, `10.2.0.0/16`, `10.3.0.0/16` → NW-FW |
| `firewall-rt` | NW-FW (native attachment) | `10.1.0.0/16` → VPC A, `10.2.0.0/16` → VPC B, `10.3.0.0/16` → ALB VPC, `0.0.0.0/0` → Egress |
| `egress-rt` | Egress VPC | `10.1.0.0/16`, `10.2.0.0/16` → NW-FW |

> **Why a separate ALB VPC?** An ALB and its EC2 targets in the same VPC communicate locally — that traffic never crosses the TGW and is therefore invisible to NW-FW. Placing the ALB in its own VPC forces every ALB ↔ EC2 packet through the TGW and through NW-FW inspection in both directions.

> **Routing symmetry:** Return routes on the Egress VPC public route table (`egress_public_to_workload_a/b`) ensure NAT GW reply traffic re-enters the TGW and passes through NW-FW before reaching workloads. This prevents asymmetric routing and `StreamExceptionPolicyPackets` alerts.

---

## Module Structure

```
nw-fw/
├── main.tf              # Root — wires all modules; post-TGW VPC routes defined here
├── variables.tf         # All input variables with inline documentation
├── outputs.tf           # TGW ID, firewall ARN, VPC IDs, instance IDs, ALB DNS name
├── data.tf              # aws_region, aws_caller_identity, aws_partition
├── versions.tf          # Terraform >= 1.3, AWS provider ~> 6.0
├── terraform.tfvars     # All variable values — edit before deploying
├── iam/
│   ├── main.tf          # EC2 IAM role, SSM managed policies, CW + S3 custom policies, instance profile
│   ├── variables.tf
│   └── outputs.tf       # role name, role ARN, instance profile name and ARN
└── modules/
    ├── firewall/
    │   ├── main.tf      # Stateless fwd-all rule group, stateful allow rule group, firewall policy
    │   ├── variables.tf
    │   ├── outputs.tf   # firewall_policy_arn
    │   └── dashboard.tf # CloudWatch dashboard (3 rows, 7 widgets)
    ├── tgw/
    │   ├── main.tf      # TGW, 4 VPC attachments, NW-FW native attachment, 3 RTs + all routes
    │   ├── variables.tf
    │   ├── outputs.tf   # tgw_id, firewall_arn, all attachment IDs
    │   └── logging.tf   # CW log groups (flow + alert) + NW-FW logging configuration
    ├── workload_vpc/
    │   ├── main.tf      # VPC, workload subnets, /28 TGW subnets, SG (ICMP+80+443), 3 SSM endpoints
    │   ├── variables.tf
    │   └── outputs.tf   # vpc_id, subnet IDs, sg_id, route_table_id
    ├── egress_vpc/
    │   ├── main.tf      # VPC, IGW, public subnets, dual NAT GWs, /28 TGW subnets, route tables
    │   ├── variables.tf
    │   └── outputs.tf   # vpc_id, tgw_subnet_ids, nat_gateway_ids, route_table_ids
    ├── alb_vpc/
    │   ├── main.tf      # VPC, IGW, public /27 subnets, /28 TGW subnets, route tables, ALB SG
    │   ├── variables.tf
    │   └── outputs.tf   # vpc_id, public_subnet_ids, tgw_subnet_ids, tgw_route_table_ids, alb_sg_id
    ├── alb/
    │   ├── main.tf      # Internet-facing ALB, ip-type target group, /index.html health check, listener
    │   ├── variables.tf
    │   └── outputs.tf   # alb_dns_name, alb_arn, target_group_arn
    └── compute/
        ├── main.tf      # 2 × EC2 (one per AZ), gp3 encrypted root volume, SSM access, httpd user_data
        ├── variables.tf
        └── outputs.tf   # instance_ids, private_ips
```

---

## Resources Created

| Resource | Count | Notes |
|---|---|---|
| VPCs | 4 | workload-a, workload-b, egress, alb |
| Transit Gateway | 1 | Default RT association/propagation disabled |
| AWS Network Firewall | 1 | Native TGW attachment — no inspection VPC |
| TGW Route Tables | 3 | spoke / firewall / egress |
| TGW Routes | 13 | Explicit routes across all three RTs (includes ALB VPC) |
| Application Load Balancer | 1 | Internet-facing, in ALB VPC public subnets |
| ALB Target Group | 1 | IP type, HTTP port 80, health check `/index.html` |
| EC2 Instances | 4 | 2 per workload VPC, one per AZ, httpd pre-installed |
| NAT Gateways | 2 | One per AZ in egress VPC |
| Elastic IPs | 2 | One per NAT GW |
| Internet Gateways | 2 | One in egress VPC, one in ALB VPC |
| SSM VPC Endpoints | 6 | ssm, ssmmessages, ec2messages × 2 workload VPCs |
| CW Log Groups | 2 | `/aws/network-firewall/<project>/flow` and `.../alert` |
| CW Dashboard | 1 | `<project_name>-nwfw-dashboard` |
| IAM Role | 1 | EC2 instance role with SSM + S3 + CW permissions |

---

## Firewall Rules

| Layer | Rule | Action |
|---|---|---|
| Stateless | All traffic (0.0.0.0/0 → 0.0.0.0/0) | Forward to stateful engine |
| Stateful sid:1 | ICMP — any source, any destination, any direction | PASS |
| Stateful sid:2 | TCP 443 from `10.0.0.0/8` → any | PASS |
| Stateful sid:3 | TCP 80 from `10.0.0.0/8` → any | PASS — covers ALB ↔ EC2 traffic |
| Default | Everything else | DROP (implicit) |

> `sid:3` covers ALB → EC2 and EC2 → ALB traffic since both `10.3.0.0/16` (ALB VPC) and `10.1.0.0/16` (VPC A) fall within `10.0.0.0/8`. No additional firewall rules are required.

---

## IAM

The `iam/` directory creates:

- **EC2 IAM Role** (`var.role_name`) — trust policy for `ec2.amazonaws.com`
- **Managed policy attachments:**
  - `AmazonSSMAutomationRole` — SSM Automation
  - `AmazonSSMManagedInstanceCore` — Session Manager, Run Command, Patch Manager
- **Custom policies:**
  - `var.policy_name` — CloudWatch access (`iam/policycw.json`)
  - `var.s3_policy` — S3 access (`iam/policys3.json`)
  - `session-manager-s3` — inline policy scoping GetObject to regional SSM S3 buckets
- **Instance Profile** — wraps the role for EC2 attachment

---

## CloudWatch Logging

NW-FW logs are sent to two CloudWatch log groups (configured in `modules/tgw/logging.tf`):

| Log Group | Type | Retention |
|---|---|---|
| `/aws/network-firewall/<project>/flow` | FLOW — every accepted/dropped connection | 30 days (configurable via `log_retention_days`) |
| `/aws/network-firewall/<project>/alert` | ALERT — stateful rule match events | 30 days (configurable via `log_retention_days`) |

---

## CloudWatch Dashboard

Dashboard name: `<project_name>-nwfw-dashboard` (deployed by `modules/firewall/dashboard.tf`).

| Row | Widget | Metric(s) | Engine |
|---|---|---|---|
| 1 | Traffic Overview AZ-a | ReceivedPackets, PassedPackets, DroppedPackets | Stateless |
| 1 | Traffic Overview AZ-b | ReceivedPackets, PassedPackets, DroppedPackets | Stateless |
| 1 | Endpoint Health | HealthyEndpoints, UnhealthyEndpoints | — |
| 2 | Dropped Packets (both AZs) | DroppedPackets per AZ | Stateless |
| 2 | Blocked & Rejected Flows | BlockedFlows, RejectedFlows per AZ | Stateful |
| 3 | Stream Exception Policy | StreamExceptionPolicyPackets — asymmetric routing indicator | Stateful |
| 3 | No Rule Group Match | NoRuleGroupMatchPackets — policy gap indicator | Stateful |

All widgets are scoped per AZ (`eu-west-1a` / `eu-west-1b`) at 1-minute resolution.

---

## Prerequisites

- AWS CLI configured (`default` profile, or set `aws_profile` in `terraform.tfvars`)
- Terraform >= 1.3
- AWS provider ~> 6.0
- Region: `eu-west-1` (Ireland) — NW-FW native TGW integration is GA here

---

## Configuration — terraform.tfvars

All variables are set in `terraform.tfvars`. Key values to review before deploying:

```hcl
aws_region   = "eu-west-1"
aws_profile  = "default"
project_name = "nw-fw-tgw"

# Workload VPC A
workload_a_vpc_cidr         = "10.1.0.0/16"
workload_a_subnet_cidrs     = ["10.1.1.0/24", "10.1.2.0/24"]
workload_a_tgw_subnet_cidrs = ["10.1.10.0/28", "10.1.11.0/28"]

# Workload VPC B
workload_b_vpc_cidr         = "10.2.0.0/16"
workload_b_subnet_cidrs     = ["10.2.1.0/24", "10.2.2.0/24"]
workload_b_tgw_subnet_cidrs = ["10.2.10.0/28", "10.2.11.0/28"]

# Egress VPC
egress_vpc_cidr            = "10.0.0.0/16"
egress_public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
egress_tgw_subnet_cidrs    = ["10.0.10.0/28", "10.0.11.0/28"]

# ALB VPC — dedicated VPC for internet-facing ALB
alb_vpc_cidr            = "10.3.0.0/16"
alb_public_subnet_cidrs = ["10.3.1.0/27", "10.3.2.0/27"]
alb_tgw_subnet_cidrs    = ["10.3.10.0/28", "10.3.11.0/28"]

# Compute — Amazon Linux 2023 eu-west-1
ami           = "ami-0720a3ca2735bf2fa"
instance_type = "t3.micro"
disk_size     = 20

# IAM
role_name   = "fw-iam-role"
policy_name = "fw-role-policy"
s3_policy   = "fw-s3-policy"
```

> **AMI note:** The AMI ID is region-specific. If you change `aws_region`, update `ami` to the correct Amazon Linux 2023 AMI for that region.

> **ALB subnet size:** ALB VPC public subnets use `/27` (32 IPs). AWS requires a minimum `/27` with at least 8 free IPs per subnet for ALB node scaling.

---

## Deploy

```bash
terraform init
terraform plan
terraform apply
```

---

## Outputs

After `terraform apply`, the following values are printed:

| Output | Description |
|---|---|
| `tgw_id` | Transit Gateway ID |
| `firewall_arn` | AWS Network Firewall ARN |
| `workload_a_vpc_id` | Workload VPC A ID |
| `workload_b_vpc_id` | Workload VPC B ID |
| `egress_vpc_id` | Egress VPC ID |
| `workload_a_instance_ids` | EC2 instance IDs in VPC A |
| `workload_a_private_ips` | Private IPs of VPC A instances |
| `workload_b_instance_ids` | EC2 instance IDs in VPC B |
| `workload_b_private_ips` | Private IPs of VPC B instances |
| `alb_dns_name` | Public DNS name of the ALB — use to test end-to-end HTTP |

---

## Test Connectivity

```bash
# Test ALB end-to-end (internet → ALB → NW-FW → EC2)
curl http://<alb_dns_name>
# Expected: <h1>Hello from ip-10-1-x-x.eu-west-1.compute.internal</h1>

# Connect to a Workload A instance via SSM (no SSH key or bastion required)
aws ssm start-session --target <workload_a_instance_id> --region eu-west-1

# East-west ping (from VPC A instance to VPC B instance — inspected by NW-FW)
ping <workload_b_private_ip>

# North-south HTTPS (should pass — TCP 443 is allowed)
curl -I https://example.com

# North-south HTTP (should pass — TCP 80 is allowed)
curl -I http://example.com
```

---

## Clean Up

```bash
terraform destroy
```

---

## References

- [AWS Network Firewall native Transit Gateway support (GA announcement)](https://aws.amazon.com/about-aws/whats-new/2025/06/aws-network-firewall-transit-gateway-native-integration/)
- [Route traffic through a TGW network function attachment](https://docs.aws.amazon.com/vpc/latest/tgw/route-traffic-nf-attachment.html)
- [AWS Network Firewall Developer Guide](https://docs.aws.amazon.com/network-firewall/latest/developerguide/what-is-aws-network-firewall.html)
- [AWS Network Firewall metrics reference](https://docs.aws.amazon.com/network-firewall/latest/developerguide/monitoring-cloudwatch.html)
- [Application Load Balancer — subnet requirements](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html#subnets-load-balancer)
- [ALB target groups — IP target type for cross-VPC targets](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)
