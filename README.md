# AWS Network Firewall — Native Transit Gateway Integration

Terraform implementation of AWS Network Firewall with a native TGW attachment (GA in `eu-west-1`). No inspection VPC required.

A dedicated **ALB VPC** hosts the internet-facing ALB. Keeping the ALB in a separate VPC forces all ALB ↔ EC2 traffic through the TGW so NW-FW inspects it in both directions.

---

## Architecture

```
                        Internet
                            │
                    IGW (ALB VPC)
                            │
              ALB VPC (10.3.0.0/16)
              ├── Public subnets /27 × 2  ← ALB nodes live here
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
 ├── EC2 AZ-a         ├── EC2 AZ-a        ├── NAT GW AZ-a
 ├── EC2 AZ-b         └── EC2 AZ-b        ├── NAT GW AZ-b
 └── TGW /28 × 2      └── TGW /28 × 2    └── IGW
```

### Traffic Flows

| Flow | Path |
|---|---|
| Inbound (ALB → EC2) | Internet → IGW → ALB → TGW spoke-rt → NW-FW → TGW firewall-rt → EC2 |
| Response (EC2 → ALB) | EC2 → TGW spoke-rt → NW-FW → TGW firewall-rt → ALB → Internet |
| East-West (A ↔ B) | Workload → TGW spoke-rt → NW-FW → TGW firewall-rt → destination VPC |
| North-South (egress) | Workload → TGW spoke-rt → NW-FW → TGW firewall-rt → Egress VPC → NAT GW → IGW |

### TGW Route Tables

| Route Table | Attached To | Routes |
|---|---|---|
| `spoke-rt` | Workload A, Workload B, ALB VPC | All traffic → NW-FW |
| `firewall-rt` | NW-FW | `10.1/16` → VPC A, `10.2/16` → VPC B, `10.3/16` → ALB VPC, `0.0.0.0/0` → Egress |
| `egress-rt` | Egress VPC | `10.1/16`, `10.2/16` → NW-FW |

---

## Firewall Rules

| Layer | Rule | Action |
|---|---|---|
| Stateless | All traffic | Forward to stateful engine |
| Stateful sid:1 | ICMP any → any | PASS |
| Stateful sid:2 | TCP 443 from `10.0.0.0/8` | PASS |
| Stateful sid:3 | TCP 80 from `10.0.0.0/8` | PASS |
| Default | Everything else | DROP |

---

## Key Design Decisions

**ALB in a separate VPC** — ALB and EC2 in the same VPC communicate locally, bypassing NW-FW. A separate VPC forces every packet through the TGW.

**ALB public subnet routes** — ALB nodes live in the public subnets, not the TGW subnets. Routes for `10.1.0.0/16` and `10.2.0.0/16` → TGW are added to the public route table so health checks and requests reach EC2 targets.

**ALB SG egress** — Egress is open to all protocols on `10.0.0.0/8`. Restricting to port 80 only blocks TCP return traffic on ephemeral ports (1024–65535), causing 504 errors.

**Post-TGW routes at root level** — VPC routes that reference the TGW ID are defined in `main.tf` (not inside VPC modules) to avoid circular dependencies. All these routes have `depends_on = [module.tgw]` to prevent `InvalidTransitGatewayID.NotFound` race conditions.

**EC2 launch order** — `compute_a` and `compute_b` depend on `module.tgw` and their respective default routes. `user_data` runs `yum install httpd` which requires the full north-south path (TGW → NW-FW → NAT GW → Internet) to be ready.

**`user_data` hostname** — Uses `$$(hostname -f)` (HCL double-dollar escape) so `$(hostname -f)` is evaluated on the instance at boot, not by Terraform at plan time.

**Routing symmetry** — Return routes on the egress public RT (`egress_public_to_workload_a/b`) ensure NAT GW reply traffic re-enters the TGW and passes through NW-FW, preventing `StreamExceptionPolicyPackets`.

---

## Module Structure

```
nw-fw/
├── main.tf              # Root — wires modules, all post-TGW VPC routes
├── variables.tf
├── outputs.tf
├── data.tf
├── versions.tf          # Terraform >= 1.3, AWS provider ~> 6.0
├── terraform.tfvars
├── iam/                 # EC2 role, SSM + CW + S3 policies, instance profile
└── modules/
    ├── firewall/        # NW-FW policy, rule groups, CW dashboard
    ├── tgw/             # TGW, attachments, route tables, NW-FW, CW logging
    ├── workload_vpc/    # VPC, subnets, SG, SSM endpoints
    ├── egress_vpc/      # VPC, IGW, NAT GWs, route tables
    ├── alb_vpc/         # VPC, IGW, public /27 subnets, TGW subnets, ALB SG
    ├── alb/             # ALB, target group (ip type), listener
    └── compute/         # 2 × EC2 per VPC, httpd user_data, SSM access
```

---

## Prerequisites

- AWS CLI configured (`default` profile, or set `aws_profile` in `terraform.tfvars`)
- Terraform >= 1.3
- Region: `eu-west-1` — NW-FW native TGW attachment is GA here

---

## Deploy

```bash
terraform init
terraform plan
terraform apply
```

> **AMI note:** `ami` in `terraform.tfvars` is region-specific. Update it if you change `aws_region`.

---

## Test

```bash
# End-to-end: Internet → ALB → NW-FW → EC2
curl http://<alb_dns_name>
# Expected: <h1>Hello from ip-10-1-x-x.eu-west-1.compute.internal</h1>

# SSM session (no SSH key needed)
aws ssm start-session --target <instance_id> --region eu-west-1

# East-west ping (VPC A → VPC B, inspected by NW-FW)
ping <workload_b_private_ip>

# North-south egress
curl -I https://example.com
```

---

## Outputs

| Output | Description |
|---|---|
| `tgw_id` | Transit Gateway ID |
| `firewall_arn` | NW-FW ARN |
| `workload_a_vpc_id` | Workload VPC A ID |
| `workload_b_vpc_id` | Workload VPC B ID |
| `egress_vpc_id` | Egress VPC ID |
| `workload_a_instance_ids` | EC2 IDs in VPC A |
| `workload_a_private_ips` | Private IPs in VPC A |
| `workload_b_instance_ids` | EC2 IDs in VPC B |
| `workload_b_private_ips` | Private IPs in VPC B |
| `alb_dns_name` | ALB public DNS name |

---

## Clean Up

```bash
terraform destroy
```

---

## References

- [NW-FW native TGW support — GA announcement](https://aws.amazon.com/about-aws/whats-new/2025/06/aws-network-firewall-transit-gateway-native-integration/)
- [Route traffic through a TGW network function attachment](https://docs.aws.amazon.com/vpc/latest/tgw/route-traffic-nf-attachment.html)
- [AWS Network Firewall Developer Guide](https://docs.aws.amazon.com/network-firewall/latest/developerguide/what-is-aws-network-firewall.html)
- [ALB subnet requirements](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html#subnets-load-balancer)
- [ALB IP target type for cross-VPC targets](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)
