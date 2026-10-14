# Roles and templates

> **You need:** Lesson 2 · **Time:** ~75 min · **Cost:** free (local) · **Start from:** `checkpoint/09-ansible`

## Why this matters

One long playbook becomes hard to read and impossible to share. Roles split it by job (SSH and
users, Docker, Linkly), each with its own defaults and files, so a play just says which jobs a
group of hosts has. A new server type is a new list of roles, not a new script.

## Concept

- **A role** is a folder with a fixed layout; Ansible finds each part by name:

  ```
  roles/linkly/
    defaults/main.yml    # its settings, with values you can override
    tasks/main.yml       # what it does
    handlers/main.yml    # what it runs when something changed
    templates/*.j2       # files with {{ variables }} in them (Jinja2)
  ```

- **Linkly's four roles:**
  - `common` (every host): packages, security updates, admins, SSH hardening;
  - `bastion`: lets SSH hop through, to SSH ports only (`PermitOpen *:22`);
  - `docker`: Docker, and the Compose plugin pinned with its sha256 (Module 6's script, as a role);
  - `linkly`: `/opt/linkly` with the Compose files and `.env`, and a systemd service, so Linkly
    starts at boot. A changed file notifies `Apply Linkly`, which runs `docker compose up` again:
    only the containers whose settings changed are recreated, and the database volume stays.
- **Variables, from weakest to strongest** (the ones you'll use): role `defaults/` → inventory
  `group_vars/all` → `group_vars/<group>` → `host_vars/<host>` → `-e` on the command line.
  Put a role's knobs in `defaults/`, and your choices in the inventory.
- **Templates:** `template:` renders a `.j2` file with the host's variables and facts. The
  `{{ ansible_managed }}` line at the top warns people the file is overwritten.
- **sshd's drop-in folder:** sshd uses the *first* value it reads for a setting, and reads
  `sshd_config.d/*.conf` in name order. `common` writes `10-hardening.conf` (before Amazon Linux's
  own `50-redhat.conf`, so it wins); on the bastion, `bastion` writes `05-bastion.conf`, so its
  `AllowTcpForwarding yes` wins over the `no` that every other host gets.
- **`assert`:** a role can refuse bad settings before it changes anything. `linkly` checks its
  four required variables first.
- **Collections:** modules come in collections. These roles use only `ansible.builtin` (part of
  ansible-core). Others, like `community.docker` or `amazon.aws`, come from Ansible Galaxy
  (`ansible-galaxy collection install`), pinned in a `requirements.yml`.

## Example

```bash
ansible-playbook site.yml      # the bastion: ok. web1: Docker installs, then "Check the settings…" fails
```

The failure is on purpose: `linkly_db_password` comes from a vault you haven't created yet
(lesson 4), and the `assert` stopped the `linkly` role before it wrote anything. (The `docker` role
comes first in the play, so Docker is already installed; run it again later and that part is `ok`.) Read
`roles/linkly/templates/env.j2` and `linkly.service.j2` to see what it will write.

Override a default for one group without touching the role:

```bash
# in inventories/lab/group_vars/bastions.yml (a new file):
bastion_permit_open: "*:22 web1:2222"
ansible-playbook site.yml --limit bastion --diff     # the PermitOpen line changes, sshd reloads
```

(Then delete the file and run it again, to put it back.)

## Lab

- [ ] Draw which roles each host gets, from `site.yml`
- [ ] Find where `linkly_port`, `common_admins` and `linkly_tag` are set, and which wins
- [ ] Override `bastion_permit_open` for the bastions group and see the diff; then undo it
- [ ] Read the `assert` in `roles/linkly/tasks/main.yml`: why letters and digits only?

## Check yourself

1. Why do role settings go in `defaults/` and not `vars/`?

<details><summary>Answer</summary>

`defaults/` are the weakest variables, so any inventory or `-e` value overrides them. `vars/` in a
role beat the inventory, which is for values the role's user should *not* change.

</details>

2. The bastion and web1 both get `common`'s `AllowTcpForwarding no`. Why can SSH still hop through
   the bastion?

<details><summary>Answer</summary>

On the bastion, `05-bastion.conf` sets `AllowTcpForwarding yes` and is read before
`10-hardening.conf`. sshd keeps the first value, so the bastion forwards (to port 22 only, by
`PermitOpen`) while web1 forwards nothing.

</details>
