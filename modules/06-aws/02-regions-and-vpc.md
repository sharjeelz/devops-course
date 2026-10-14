# Regions and VPCs

> **You need:** Lesson 1 (signed in with `AWS_PROFILE=linkly`, `AWS_REGION` set) · **Time:** ~75 min · **Cost:** free (VPCs, subnets and route tables cost nothing) · **Start from:** `checkpoint/06-aws`

## Why this matters

Every server you run in AWS lives in a network you control: which addresses it gets, whether the
internet can reach it, and what it can reach. In Module 0 your laptop's network was just there.
Here you build one from parts, and the parts are the same ones Terraform will create in Module 7.

## Concept

- **Region:** a geographic area (`eu-central-1` is Frankfurt) with its own copy of most services.
  **Availability Zones** (AZs: `eu-central-1a`, `-b`, `-c`) are separate data centres inside it.
  Spreading across AZs survives one failing.
- **VPC:** your private network in a region, with an address range in CIDR notation:
  `10.0.0.0/16` is 65,536 addresses, `10.0.1.0/24` is 256.
- **Subnet:** a slice of the VPC in one AZ.
- **Internet gateway (IGW):** the VPC's door to the internet.
- **Route table:** where traffic goes. A **public subnet** is simply one whose route table sends
  `0.0.0.0/0` (everything else) to the internet gateway.
- **Private subnets** have no such route; reaching the internet from them needs a **NAT gateway**,
  which costs about $0.045/hour plus data. We skip it here; Module 8 discusses when it's worth it.
- **Security groups** (next lesson) are firewalls around each instance, and *stateful*: allowed
  traffic's replies are allowed automatically. **Network ACLs** are a second, stateless layer per
  subnet; the defaults are fine.

## Example

Every resource is tagged `Project=linkly-course`, so the clean-up script can find it.

```bash
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Project,Value=linkly-course},{Key=Name,Value=linkly-course}]' \
  --query Vpc.VpcId --output text)
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'

SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.1.0/24 --availability-zone "${AWS_REGION}a" \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Project,Value=linkly-course},{Key=Name,Value=linkly-course-public}]' \
  --query Subnet.SubnetId --output text)

IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Project,Value=linkly-course}]' \
  --query InternetGateway.InternetGatewayId --output text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"

RTB_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Project,Value=linkly-course}]' \
  --query RouteTable.RouteTableId --output text)
aws ec2 create-route --route-table-id "$RTB_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
aws ec2 associate-route-table --route-table-id "$RTB_ID" --subnet-id "$SUBNET_ID"
aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_ID" --map-public-ip-on-launch

aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --query 'Vpcs[0].[VpcId,CidrBlock]'
```

Keep these variables in your terminal (or write them down): lessons 3–5 use them.

## Lab

- [ ] Choose a region and say why
- [ ] Create a VPC and a public subnet, tagged for the course
- [ ] Give the subnet a route to the internet
- [ ] Explain what makes a subnet "public"

## Check yourself

1. How many addresses are in `10.0.1.0/24`, and why does it fit inside `10.0.0.0/16`?

<details><summary>Answer</summary>

256 (AWS reserves 5 in each subnet). `/16` fixes only the first 16 bits (`10.0`), so every
`10.0.x.y` address, including all of `10.0.1.*`, is inside it.

</details>

2. What exactly makes a subnet public?

<details><summary>Answer</summary>

Its route table has a route for `0.0.0.0/0` to an internet gateway. Instances in it also need a
public IP to be reachable, which `--map-public-ip-on-launch` gives them.

</details>

3. Why might you deliberately put a database in a private subnet?

<details><summary>Answer</summary>

Nothing on the internet can even try to connect to it, because there's no route in. Only things
inside the VPC can reach it, through the security groups you allow.

</details>

## Clean up

Nothing here costs money, so you can keep it for lesson 3. To remove everything at any point,
run lesson 7's clean-up script.
