
import json
import hashlib


def generate_hash(data: dict) -> str:
    raw = json.dumps(data, sort_keys=True, default=str).encode("utf-8")

    return hashlib.sha256(raw).hexdigest()