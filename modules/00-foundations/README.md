# Foundations Check

> **You need:** you've used a terminal and Git before · **Time:** ~6–8 hours · **Start from:** `checkpoint/00-foundations`

This module isn't a from-zero Linux course. It checks the things every later module leans on
(Linux, networking, Git) and fills the gaps. Then it ends with the real payoff: you run
**Linkly**, the app you'll grow for the rest of the course, by hand on a bare Linux machine.
Every step you do by hand here is one you'll automate later, so take notes on what hurts.

## What you'll have at the end

Linkly running on Linux: the web page behind nginx on port 8080, the API on 8000, a worker
counting clicks, with Postgres and Redis underneath. Plus a written list of every manual step it took.

## Before you start (Windows)

Every lab runs on Linux. On Windows, install WSL2 with Ubuntu: open PowerShell **as administrator** and run

```powershell
wsl --install -d Ubuntu-24.04
```

Reboot, open "Ubuntu" from the Start menu, and pick a username and password. Work **inside
your Linux home folder** (`cd ~`), not under `/mnt/c/...`: it's much faster, and file
permissions behave like a real server's. A VM (VirtualBox, UTM) running Ubuntu 24.04 works too.

## Lessons

1. [Linux refresher](01-linux-refresher.md): files, users, permissions, processes, packages, services
2. [Networking for DevOps](02-networking.md): ports, DNS, HTTP, and why "it works on my machine" happens
3. [Git refresher](03-git.md): branches, remotes, conflicts, and keeping secrets out
4. [Run Linkly by hand](04-run-linkly-by-hand.md): the whole app, one manual step at a time
5. [Foundations self-test](05-self-test.md): check yourself before Module 1
