# Linux refresher

> **You need:** a Linux terminal (WSL2 Ubuntu or a VM) · **Time:** ~90 min · **Start from:** `checkpoint/00-foundations`

## Why this matters

Every server you deploy to, every container you build and every CI runner that tests your code
is Linux. When something breaks at 2 a.m., you'll be reading logs, checking permissions and
restarting services from a terminal, with no GUI. This lesson makes sure those moves are automatic.

## Concept

Six ideas cover most of what you'll do on a server:

- **One file tree.** Everything hangs off `/`. The places you'll visit most:
  `/etc` (configuration), `/var/log` (logs), `/home/<you>` (your files), `/usr/bin` (programs),
  `/tmp` (scratch, wiped on reboot).
- **Users and groups.** Every file has an owner and a group. Services run as their own users
  (`postgres`, `www-data`) so a bug in one can't touch the others' files.
- **Permissions.** `rwx` (read, write, execute) for the owner, the group and everyone else.
  `rwxr-x---` is `750`: owner everything, group read and execute, others nothing.
- **Processes and signals.** Every running program is a process with a PID. `kill` asks it to
  stop (SIGTERM, so it can clean up); `kill -9` forces it (SIGKILL, no clean-up).
- **Packages.** `apt` installs software and its dependencies from Ubuntu's repositories.
- **Services.** Long-running programs are managed by `systemd`: `systemctl` starts and stops
  them, and `journalctl` shows their logs.

And one more that bites everyone: **environment variables** are passed from a process to the
processes it starts, but only if they're *exported*.

## Example

```bash
cat /etc/os-release                 # which Linux is this?
ls -la /etc | head                  # long listing: permissions, owner, group, size, date
ps aux | grep -i ssh                # find processes by name
sudo systemctl status ssh           # is a service running? (install it with: sudo apt install -y openssh-server)
journalctl -u ssh --since "10 min ago"   # that service's recent logs
echo $PATH                          # where the shell looks for programs
```

Permissions in action:

```bash
echo "secret plans" > notes.txt
ls -l notes.txt          # -rw-r--r--  : everyone can read it
chmod 640 notes.txt
ls -l notes.txt          # -rw-r-----  : owner rw, group r, others nothing
```

Exported vs not exported:

```bash
GREETING=hi
bash -c 'echo "child sees: $GREETING"'    # child sees:      (empty)
export GREETING=hi
bash -c 'echo "child sees: $GREETING"'    # child sees: hi
```

## Lab

- [ ] Find which Ubuntu version you're on
- [ ] Create a user `deploy` and a group `apps`, and add `deploy` to `apps`
- [ ] Make a file only `deploy` can read and prove another user can't
- [ ] Install `htop` with apt and find the process using the most memory
- [ ] Write a script `hello.sh` that prints the date and your user, make it executable, and run it
- [ ] Explain in one sentence why `export` mattered in the `GREETING` example

Hints: `sudo adduser`, `sudo groupadd`, `sudo usermod -aG`, `sudo -u deploy cat <file>`,
`chmod +x`, `whoami`, `date`.

## Check yourself

1. What does `chmod 750 deploy.sh` allow, and for whom?

<details><summary>Answer</summary>

The owner can read, write and execute it; the group can read and execute it; everyone else can do nothing.

</details>

2. A service is misbehaving. Where do you look first?

<details><summary>Answer</summary>

`systemctl status <name>` for its state and last log lines, then `journalctl -u <name>` for the
full log (add `-f` to follow it live).

</details>

3. What's the difference between `kill <pid>` and `kill -9 <pid>`?

<details><summary>Answer</summary>

`kill` sends SIGTERM, which asks the process to shut down cleanly (close files, finish requests).
`kill -9` sends SIGKILL: the kernel stops it immediately, with no clean-up. Use `-9` only when
a polite kill doesn't work.

</details>

4. Why use `sudo` for one command instead of logging in as root?

<details><summary>Answer</summary>

You only get root powers for the command that needs them, every use is logged, and a typo in
your everyday commands can't wreck the system.

</details>

## Stretch

Make `hello.sh` run every minute with a **systemd timer** (a `.service` plus a `.timer` unit in
`/etc/systemd/system/`), then find its output with `journalctl`.
