import re
import secrets
import string

ALPHABET = string.digits + string.ascii_letters
CODE_RE = re.compile(r"[0-9A-Za-z]{7}")


def new_code(length: int = 7) -> str:
    """A random short code like 'a8Zk2Qp'. 62^7 ≈ 3.5 trillion possibilities."""
    return "".join(secrets.choice(ALPHABET) for _ in range(length))
