import hashlib

def strong_etag_bytes(b: bytes) -> str:
    return '"'+hashlib.sha256(b).hexdigest()+'"'

def strong_etag_text(s: str) -> str:
    return strong_etag_bytes(s.encode())

def combined_etag(etags: list[str]) -> str | None:
    parts=[e.strip('"') for e in etags if e]
    if not parts:
        return None
    canon=",".join(sorted(parts))
    return strong_etag_bytes(canon.encode())
