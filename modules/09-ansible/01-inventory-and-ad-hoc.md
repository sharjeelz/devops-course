# Inventory and ad-hoc commands

> **You need:** Module 1 (Docker) · **Time:** ~60 min · **Cost:** free (local) · **Start from:** `checkpoint/09-ansible`

## Why this matters

Terraform made Module 7's server; a script inside it installed Docker and Linkly once, on first
boot. Then what? A security fix for SSH, a new admin, a changed setting: you'd log in and type,
and the next server would be a little different from the last. Configuration management keeps a
written description of each machine and makes the machines match it, today and every time after.

## Concept

- **Ansible is agentless:** nothing to install on the servers beyond SSH and Python, which Amazon
  Linux already has. You run it from a **control node** (your laptop, a CI runner) and it pushes
  the work over SSH.
- **Inventory:** the list of machines, in groups. `inventories/lab/hosts.yml` has two groups:
  `bastions` (the host `bastion`) and `linkly` (the host `web1`). Variables for a group live in
  `group_vars/<group>.yml` or `group_vars/<group>/*.yml`.
- **A bastion** (jump host) is the one machine reachable from outside; the others sit in a private
  network. SSH hops through it: `ssh -J ec2-user@bastion ec2-user@web1`. In the inventory, that's
  `ansible_ssh_common_args: -o ProxyJump=ec2-user@bastion` on the `linkly` group.
- **Modules** do the work: `ansible.builtin.ping`, `dnf`, `copy`, `template`, `systemd_service`…
  An **ad-hoc command** runs one module on some hosts: `ansible <hosts> -m <module> -a <args>`.
- **`become`** (`-b`): run as root through sudo, the way `ec2-user` does on EC2.

The lab (`app/linkly/ansible/lab/compose.yaml`) imitates a small AWS setup:

```
 your laptop
 └─ control ── outside network ── bastion ── inside network ── web1 (port 8080 → localhost:18081)
```

`bastion` and `web1` are Amazon Linux 2023, the image Module 7's server runs, booting systemd and
sshd with an `ec2-user` who may sudo. `web1` isn't on the control node's network at all.

## Example

```bash
cd app/linkly/ansible/lab
docker compose up -d --build          # a few minutes the first time
docker compose exec control bash      # you're now on the control node, in app/linkly/ansible
```

On EC2 your key pair goes into `~/.ssh/authorized_keys` on the server. In the lab the hosts read it
from a shared volume, `/keys`:

```bash
ssh-keygen -t ed25519 -N "" -f /keys/id_ed25519
cp /keys/id_ed25519.pub /keys/authorized_keys
ansible all -m ansible.builtin.ping                     # bastion | SUCCESS, web1 | SUCCESS
ansible-inventory --graph                               # the groups
ansible linkly -a "cat /etc/os-release" | head -3       # -m command is the default module
ansible all -b -a "whoami"                              # root, through sudo
ssh ec2-user@web1                                       # fails: web1 isn't on this network
ssh -J ec2-user@bastion ec2-user@web1 hostname          # web1, through the bastion
```

## Lab

- [ ] Start the lab and open a shell on the control node
- [ ] Create the lab's key and ping both hosts
- [ ] Show that web1 is reachable only through the bastion
- [ ] Find web1's free memory with an ad-hoc command (`-m ansible.builtin.setup -a 'filter=ansible_memfree_mb'`)

## Check yourself

1. What has to be installed on a server before Ansible can manage it?

<details><summary>Answer</summary>

An SSH server, a user you can log in as (with sudo for `become`), and Python. No agent, no
daemon. Amazon Linux, Ubuntu and most server images have all three.

</details>

2. Why does `web1` in the inventory need `ProxyJump`, and what would that look like on AWS?

<details><summary>Answer</summary>

The control node can't reach web1's network, only the bastion's. On AWS: web1 in a private subnet
with no public IP, the bastion in a public subnet whose security group allows SSH from your
address only, and web1's security group allowing SSH from the bastion only.

</details>

## Clean up

Keep the lab for the next lessons. To stop it: `docker compose stop`; to delete it and its volumes:
`docker compose down -v`.
