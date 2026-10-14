# Foundations self-test

> **Time:** ~30 min · Be honest: this is for you.

## Why this matters

Every module after this one assumes these basics. Ten minutes finding a gap now saves hours of
confusion in the middle of a Kubernetes lab later.

## Lab

Tick only what you can do **without looking it up**:

- [ ] I can find which process is listening on a port
- [ ] I can read and change a file's permissions with chmod, in numbers and letters
- [ ] I can create a user, add it to a group, and run a command as that user
- [ ] I can start, stop and read the logs of a systemd service
- [ ] I can explain why an environment variable needs `export`
- [ ] I can say whether a program bound to 127.0.0.1 is reachable from another machine
- [ ] I can find what a domain name resolves to
- [ ] I can read a `curl -v` response and name its status code family
- [ ] I can create a branch, commit, push it and open a pull request
- [ ] I can resolve a merge conflict
- [ ] I can keep a secrets file out of Git and say what to do if one leaks
- [ ] I can start Linkly's API and worker by hand and explain what each needs

## Check yourself

1. Which command shows listening TCP ports with their programs?

<details><summary>Answer</summary>

`sudo ss -tlnp`

</details>

2. What permissions does `640` give?

<details><summary>Answer</summary>

Owner read and write, group read, others nothing (`rw-r-----`).

</details>

3. Where do a systemd service's logs go, and how do you follow them live?

<details><summary>Answer</summary>

The journal: `journalctl -u <service> -f`.

</details>

4. Your API listens on `127.0.0.1:8000`. Can nginx on the same machine reach it? Can your laptop?

<details><summary>Answer</summary>

nginx can, because it's on the same machine. Your laptop can't connect to it directly.

</details>

5. nginx returns `502`. What's the most likely cause?

<details><summary>Answer</summary>

The program behind it (the API) isn't running, crashed, or is on a different port than nginx's `proxy_pass`.

</details>

6. What's the difference between an A record and a CNAME?

<details><summary>Answer</summary>

An A record maps a name to an IP address; a CNAME maps a name to another name.

</details>

7. You pushed an API key to GitHub. What's the first thing you do?

<details><summary>Answer</summary>

Revoke and replace the key. Cleaning Git history comes after, because the old key must be
assumed stolen already.

</details>

8. `git revert` or `git reset` for a bad commit on a shared branch?

<details><summary>Answer</summary>

`git revert`.

</details>

9. Why does Linkly's worker exist instead of the API counting clicks in Postgres directly?

<details><summary>Answer</summary>

Redirects stay fast: the API only drops the click on a Redis queue, and the worker applies
clicks to Postgres in batches, out of the way of users.

</details>

10. Name two things that broke or annoyed you in Lesson 4 that you'd like automated.

<details><summary>Answer</summary>

There's no single right answer. Typical ones: re-exporting variables in every terminal,
starting things in the right order, nothing restarting after a reboot, copying files by hand.
Keep your list for Module 1.

</details>

Not sure about 3 or more? Redo that lesson's lab before Module 1.
