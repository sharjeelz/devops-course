# Git refresher

> **You need:** a GitHub account · **Time:** ~75 min

## Why this matters

In DevOps everything is code in Git: the app, the pipeline that builds it, the infrastructure it
runs on. Git history becomes your audit log ("who changed the firewall rule, and why?"), and
from Module 5 on, a commit to Git is literally how you deploy. Being fluent with branches and
conflicts isn't optional.

## Concept

- **Commits are snapshots**, each pointing at its parent. A **branch** is just a movable name
  for one commit; `HEAD` is the one you're on.
- **Remotes** are other copies of the repo. `origin` is the one you cloned from; your fork on
  GitHub is usually `origin`, and the original repo is often added as `upstream`.
- **Merge vs rebase.** Merge joins two histories with a merge commit. Rebase replays your
  commits on top of another branch, giving a straight line, but it rewrites them, so never
  rebase commits other people already have.
- **`.gitignore`** keeps files out of Git: build output, virtual environments, and above all
  **secrets** (`.env`, keys).
- **A secret pushed is a secret leaked.** Deleting it in a later commit doesn't help, because
  it's still in history and bots scan GitHub for keys within minutes. Rotate the secret first,
  then clean history.

## Example

Fork this course repo on GitHub. In the fork dialog, **untick "Copy the `main` branch only"**: the
`checkpoint/...` branches every module starts from live on other branches.

On a fresh Ubuntu, tell Git who you are and log in to GitHub once (GitHub no longer accepts your
password for `git push`; the GitHub CLI sets up a token for you):

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
sudo apt install -y gh && gh auth login        # choose GitHub.com, HTTPS, and log in with a browser
```

Then:

```bash
cd ~
git clone https://github.com/<you>/devops-course.git
cd devops-course
git switch checkpoint/00-foundations      # "invalid reference"? See the note below
git switch -c my-notes
echo "Started Module 0 on $(date +%F)" > MY-NOTES.md
git add MY-NOTES.md
git commit -m "Start my notes"
git push -u origin my-notes
git log --oneline --graph --all | head -20
```

> **Forked with `main` only?** Fetch the checkpoints from the original repo instead:
> `git remote add upstream https://github.com/<course-owner>/devops-course.git && git fetch upstream && git switch -c checkpoint/00-foundations upstream/checkpoint/00-foundations`

`git add -p` is worth learning: it shows each change and asks whether to stage it, so you
commit exactly what you meant to.

## Lab

- [ ] Clone your fork of the course repo
- [ ] Check out `checkpoint/00-foundations`
- [ ] Create a branch, change Linkly's page title, commit and push it
- [ ] Make a merge conflict on purpose and resolve it
- [ ] Add a `.env` file and prove `.gitignore` keeps it out of `git status`

Hint for the conflict: make two branches from the same commit, change the same line of
`app/linkly/web/index.html` differently in each, then merge one into the other.

## Check yourself

1. You committed a bug that's already pushed and shared. `git reset` or `git revert`?

<details><summary>Answer</summary>

`git revert <commit>`: it adds a new commit that undoes the bad one, so nobody else's history
breaks. `git reset` rewrites history and is only safe for commits that haven't left your machine.

</details>

2. What is `origin`?

<details><summary>Answer</summary>

Just a name for a remote, by default the URL you cloned from. There's nothing special about it
beyond that convention.

</details>

3. Why does rebasing a shared branch cause trouble?

<details><summary>Answer</summary>

Rebase creates new commits with new IDs. Anyone who based work on the old commits now has a
history that disagrees with the branch, and has to untangle it.

</details>
