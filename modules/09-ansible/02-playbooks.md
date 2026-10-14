# Playbooks and idempotence

> **You need:** Lesson 1 (lab running) · **Time:** ~75 min · **Cost:** free (local) · **Start from:** `checkpoint/09-ansible`

## Why this matters

A shell script says *what to do*: install this, append that line. Run it twice and you get two
lines, or an error. A playbook says *how things should be*: this package present, this line in that
file, this service running. Ansible checks each one and changes only what's different, so running
it again is safe, and running it every day keeps the machines from drifting.

## Concept

- **A playbook** is a list of **plays**; a play maps hosts to tasks (or roles, lesson 3).
  `site.yml` has three plays: every host, the bastions, Linkly's servers.
- **A task** calls one module with arguments, and has a `name` that says what it ensures:

  ```yaml
  - name: Install the basics
    ansible.builtin.dnf:
      name: [tar, jq, dnf-automatic]
      state: present
  ```

- **ok / changed:** each task reports `ok` (already so) or `changed` (Ansible fixed it). That's
  **idempotence**: the second run of a good playbook is all `ok`, and `changed=0` in the recap.
- **Handlers** run only when a task that `notify`s them changed something, once, at the end of the
  play: reload sshd only when its config changed.
- **`validate`:** check a file before it replaces the old one. `sshd -t -f %s` refuses an SSH
  config with a mistake in it, so a typo can't lock you out of every server at once.
- **Check mode:** `--check --diff` shows what *would* change, line by line, without changing it.
- **Facts:** at the start of a play Ansible gathers facts about each host
  (`ansible_facts['architecture']`, the OS, memory), for tasks to use.

## Example

The `common` role's tasks (`roles/common/tasks/main.yml`) are a good first read: packages,
automatic security updates (`dnf-automatic`), admins with their SSH keys, sudo, and SSH hardening.
Run just the bastion for now (Linkly's server needs a password first, lesson 4):

```bash
ansible-playbook site.yml --limit bastion          # changed=11 in the recap at the end
ansible-playbook site.yml --limit bastion          # again: changed=0
```

See it from the outside:

```bash
ssh -o PubkeyAuthentication=no ec2-user@bastion   # Permission denied (publickey): no passwords offered
ssh alice@bastion sudo -n true && echo alice may sudo     # an admin from group_vars/all.yml
```

Then cause some drift by hand, see it, and let Ansible put it back:

```bash
ansible bastion -b -m ansible.builtin.file -a "path=/etc/ssh/sshd_config.d/10-hardening.conf state=absent"
ansible-playbook site.yml --limit bastion --check --diff   # would change: the file, shown line by line
ansible-playbook site.yml --limit bastion                  # changed=2: the file is back, sshd reloaded
```

> **Check mode on a brand-new host** fails early: it doesn't really install `dnf-automatic`, so
> the next task finds no `/etc/dnf/automatic.conf`. Tasks that depend on earlier ones can't be
> predicted. Check mode is for hosts that are already configured: it finds drift.

> **A gotcha:** Ansible keeps each SSH connection open for a minute after a run
> (`ControlPersist`) and reuses it. A change that would block *new* connections (like a wrong
> bastion setting) can look fine until that minute is up. Test SSH changes with a fresh `ssh`.

## Lab

- [ ] Run site.yml on the bastion, then again (`changed=0`)
- [ ] Confirm password logins are refused and alice can sudo
- [ ] Delete the hardening file by hand, find it with `--check --diff`, and let the next run restore it
- [ ] Add `htop` to `common_packages` in `inventories/lab/group_vars/all.yml`; what changes on the next run? (Not in Amazon Linux? Read the error, then remove it.)

## Check yourself

1. Why is `lineinfile` with a `regexp` idempotent, where `echo "x = 1" >> file` isn't?

<details><summary>Answer</summary>

`lineinfile` looks for a line matching the regexp and makes it equal `line`: present and right is
`ok`, otherwise it replaces or adds it once. `>>` appends every time it runs.

</details>

2. What protects you from an SSH config mistake that would lock you out?

<details><summary>Answer</summary>

`validate: /usr/sbin/sshd -t -f %s` on the template task: Ansible writes the new file to a temporary
path, runs sshd's own check on it, and only moves it into place if the check passes. The handler
then *reloads* sshd, which keeps existing sessions open.

</details>
