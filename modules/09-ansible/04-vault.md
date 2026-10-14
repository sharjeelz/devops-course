# Secrets with Ansible Vault

> **You need:** Lesson 3 · **Time:** ~60 min · **Cost:** free (local) · **Start from:** `checkpoint/09-ansible`

## Why this matters

Linkly's server needs a database password, and the inventory lives in Git. Module 8 kept its
password in AWS Secrets Manager; for a few servers configured by Ansible, the usual answer is
**Ansible Vault**: the secret sits in Git, encrypted, next to the variables that use it, and only
someone with the vault password can read it.

## Concept

- **`ansible-vault create|edit|view|encrypt|decrypt`** manage files encrypted with AES-256. The
  file is text that starts with `$ANSIBLE_VAULT;1.1;AES256`, so Git can store it; diffs are useless,
  which is why only secrets go in it.
- **The `vault_` convention:** `group_vars/linkly/vault.yml` (encrypted) holds
  `vault_linkly_db_password`; `group_vars/linkly/vars.yml` (plain) says
  `linkly_db_password: "{{ vault_linkly_db_password }}"`. Searching the plain files still shows
  where every secret is used.
- **The vault password** is typed (`--ask-vault-pass`), or read from a file outside Git
  (`--vault-password-file ~/.linkly-vault-pass`), or in CI from a secret.
- **`no_log: true`** on a task hides its arguments and result from the output: the `.env` template
  and the settings check in the `linkly` role use it, so the password never appears in a log.
- **What changing it means:** Postgres takes `POSTGRES_PASSWORD` only when its data volume is
  created. Change the vault later and the api gets the new password while Postgres still has the
  old one. To rotate: change the user's password in Postgres first
  (`docker compose exec postgres psql -U linkly -c "ALTER USER linkly PASSWORD '<new>'"`), then
  the vault, then run the playbook.
- **Letters and digits only:** the password goes into `DATABASE_URL` unescaped, so the role
  refuses anything else. `openssl rand -hex 16` gives 32 safe characters.

## Example

On the control node:

```bash
openssl rand -hex 16 2>/dev/null || python -c 'import secrets; print(secrets.token_hex(16))'
ansible-vault create inventories/lab/group_vars/linkly/vault.yml
#   New Vault password: (choose one)    then, in the editor:
#   vault_linkly_db_password: <the 32 characters>
head -1 inventories/lab/group_vars/linkly/vault.yml        # $ANSIBLE_VAULT;1.1;AES256
ansible-playbook site.yml --ask-vault-pass                 # everything; Linkly starts on web1
```

Open <http://localhost:18081> on your laptop: Linkly, from your published images, on a server
Ansible configured. Then check the secret stayed secret:

```bash
ansible-vault view inventories/lab/group_vars/linkly/vault.yml --ask-vault-pass
ansible web1 -b -a "stat -c '%a %U' /opt/linkly/.env"              # 600 root
ansible-playbook site.yml --ask-vault-pass | grep -c <the password>   # 0
```

Commit `vault.yml` in a real project. (The lab's file is yours to keep or delete; the rehearsal in
lesson 5 makes its own.)

## Lab

- [ ] Create the vault and bring Linkly up on web1
- [ ] Shorten a link at <http://localhost:18081>
- [ ] Find the two tasks with `no_log: true` and say what each would print without it
- [ ] Use a password file instead of typing: `--vault-password-file`, kept outside the repo

## Check yourself

1. Someone gets your Git repository but not the vault password. What can they learn?

<details><summary>Answer</summary>

That a `vault_linkly_db_password` exists and where it's used, but not its value. Vault files are
encrypted with a key derived from the vault password, so a weak vault password is the weak point:
make it long and random.

</details>

2. You change `vault_linkly_db_password` and run the playbook. Linkly breaks. Why?

<details><summary>Answer</summary>

The api now connects with the new password, but Postgres set its password once, when the volume
was created. Change it inside Postgres first (`ALTER USER`), then the vault, then run the playbook.

</details>
