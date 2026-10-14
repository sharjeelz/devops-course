#!/usr/bin/env python3
"""Checks every AWS CLI command in lessons and scripts without an AWS account.

The AWS CLI validates a command (service, operation, options, parameter shapes, file:// JSON)
before it sends anything. This tool runs each command with fake credentials against a dead local
endpoint: a valid command gets as far as "could not connect", an invalid one fails earlier with
its real error. Shell variables, $(...) and <placeholders> are replaced with harmless dummies.

    python3 tools/check-aws-commands.py modules/06-aws/*.md app/linkly/aws/*.sh
"""
import os
import re
import shlex
import subprocess
import sys
import tempfile

SERVICES = r"(?:ec2|s3api|s3|ecr|iam|sts|ssm|budgets|resourcegroupstaggingapi|sso|configure|ce|cloudwatch|logs)"
CONNECT_FAILED = ("Could not connect to the endpoint URL", "Connect timeout on endpoint URL", "EndpointConnectionError")
SKIP = (re.compile(r"^aws (--version|configure( |$)|sso login)"), re.compile(r" help$"))

DUMMIES = [  # (name pattern, value) for $VARS, checked in order
    (r"ACCOUNT", "123456789012"), (r"REGION", "eu-central-1"), (r"VPC", "vpc-0123456789abcdef0"),
    (r"SUBNET", "subnet-0123456789abcdef0"), (r"IGW", "igw-0123456789abcdef0"), (r"RTB|ROUTE", "rtb-0123456789abcdef0"),
    (r"SG|GROUP", "sg-0123456789abcdef0"), (r"INSTANCE", "i-0123456789abcdef0"), (r"AMI|IMAGE_ID", "ami-0123456789abcdef0"),
    (r"BUCKET", "linkly-course-example"), (r"IP", "203.0.113.10"), (r"TAG", "sha-abc1234"), (r"REPO", "linkly-api"),
    (r"ARN", "arn:aws:iam::123456789012:role/linkly-course-ec2"), (r"ASSOC", "rtbassoc-0123456789abcdef0"),
]


EXACT = {  # variables whose meaning isn't in their name
    "tag": "Name=tag:Project,Values=linkly-course",            # cleanup.sh's tag filter
    "batch": r'{\"Objects\":[{\"Key\":\"k\",\"VersionId\":\"v\"}]}',  # JSON, used inside "..."
    "name": "linkly-api",
}


def dummy(name: str) -> str:
    if name in EXACT:
        return EXACT[name]
    for pat, val in DUMMIES:
        if re.search(pat, name, re.I):
            return val
    return "x"


def substitute(cmd: str) -> str:
    out, i, depth = [], 0, 0
    while i < len(cmd):  # replace $( ... ) (possibly nested) with a dummy
        if cmd.startswith("$(", i):
            j, depth = i + 2, 1
            while j < len(cmd) and depth:
                depth += {"(": 1, ")": -1}.get(cmd[j], 0)
                j += 1
            out.append("x")
            i = j
            continue
        out.append(cmd[i])
        i += 1
    cmd = "".join(out)
    cmd = re.sub(r"\$\{(\w+)[^}]*\}", lambda m: dummy(m.group(1)), cmd)
    cmd = re.sub(r"\$(\w+)", lambda m: dummy(m.group(1)), cmd)
    cmd = re.sub(r"<[^<>\n]+>", "x", cmd)   # <placeholders>, even with spaces: <a build>
    return cmd


def cut_at_shell_operator(cmd: str) -> str:
    """Keep the aws part: stop at an unquoted |, >, ;, && or ) ."""
    quote = None
    for i, ch in enumerate(cmd):
        if quote:
            if ch == quote:
                quote = None
            continue
        if ch in "'\"":
            quote = ch
        elif ch in "|>;)" or cmd.startswith("&&", i):
            return cmd[:i].strip()
        elif ch == "#" and (i == 0 or cmd[i - 1].isspace()):  # a trailing comment
            return cmd[:i].strip()
    return cmd.strip()


def logical_lines(text: str):
    buf = ""
    for line in text.splitlines():
        if line.rstrip().endswith("\\"):
            buf += line.rstrip()[:-1] + " "
            continue
        yield buf + line
        buf = ""


def commands_in(path: str):
    text = open(path, encoding="utf-8").read()
    if path.endswith(".md"):
        blocks = re.findall(r"```(?:bash|sh)\n(.*?)```", text, re.S)
        text = "\n".join(blocks)
    for line in logical_lines(text):
        if line.lstrip().startswith("#"):
            continue
        if path.endswith(".md"):  # lessons' <placeholders> contain ">", which isn't a redirect
            line = re.sub(r"<[^<>\n]+>", "x", line)
        for m in re.finditer(r"(?<![\w-])(aws|run) (" + SERVICES + r" [\w-]+.*)", line):
            if m.group(1) == "run" and not path.endswith(".sh"):
                continue
            if line[: m.start()].count('"') % 2:  # inside a quoted string (e.g. an echo message)
                continue
            yield "aws " + cut_at_shell_operator(m.group(2))


def check(cmd: str, env: dict) -> tuple[bool, str]:
    if any(p.search(cmd) for p in SKIP):
        return True, "skipped (doesn't call AWS)"
    try:
        argv = shlex.split(substitute(cmd))
    except ValueError as e:
        return False, f"can't parse: {e}"
    for a in argv:
        if a.startswith("file://") and not os.path.exists(a[len("file://"):]):
            return False, f"missing file {a}"
    argv += ["--endpoint-url", "http://127.0.0.1:9", "--cli-connect-timeout", "1", "--cli-read-timeout", "1"]
    r = subprocess.run(argv, capture_output=True, text=True, env=env, timeout=60, shell=os.name == "nt",
                       stdin=subprocess.DEVNULL)  # "aws s3 cp - ..." reads stdin: give it none
    out = (r.stderr + r.stdout).strip()
    if any(s in out for s in CONNECT_FAILED):
        return True, "valid"
    return False, out.splitlines()[-1] if out else f"exit {r.returncode} with no output"


def main(paths):
    tmp = tempfile.mkdtemp()
    with open(os.path.join(tmp, "config"), "w") as f:
        f.write("[default]\nregion = eu-central-1\n[profile linkly]\nregion = eu-central-1\n")
    with open(os.path.join(tmp, "credentials"), "w") as f:
        for p in ("default", "linkly"):
            f.write(f"[{p}]\naws_access_key_id = AKIAFAKEFAKEFAKEFAKE\naws_secret_access_key = fake\n")
    env = dict(os.environ, AWS_CONFIG_FILE=os.path.join(tmp, "config"), AWS_SHARED_CREDENTIALS_FILE=os.path.join(tmp, "credentials"),
               AWS_MAX_ATTEMPTS="1", AWS_RETRY_MODE="standard", AWS_PAGER="", AWS_REGION="eu-central-1")
    env.pop("AWS_PROFILE", None)

    # Self-test: the checker must tell a good command from a bad one.
    good_ok, _ = check("aws ec2 describe-vpcs", env)
    bad_ok, _ = check("aws ec2 run-instances --image-id ami-1 --instance-typo t3.micro", env)
    if not good_ok or bad_ok:
        print("checker self-test failed: can't tell valid from invalid commands here")
        return 2

    seen, failed = set(), 0
    for path in paths:
        for cmd in commands_in(path):
            if (path, cmd) in seen:
                continue
            seen.add((path, cmd))
            ok, why = check(cmd, env)
            failed += not ok
            print(f"{'ok  ' if ok else 'FAIL'} {path}: {cmd[:110]}{'...' if len(cmd) > 110 else ''}" + ("" if ok else f"\n     -> {why}"))
    print(f"{len(seen)} commands checked, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
