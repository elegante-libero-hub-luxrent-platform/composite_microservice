import base64
import json
from typing import Dict, Optional


def encode_token(payload: Dict[str, object]) -> str:
    packed = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
    return base64.urlsafe_b64encode(packed).decode("utf-8")


def decode_token(token: str) -> Dict[str, object]:
    raw = base64.urlsafe_b64decode(token.encode("utf-8"))
    return json.loads(raw.decode("utf-8"))


def merge_tokens(tokens: Dict[str, Optional[str]]) -> Optional[str]:
    compact = {k: v for k, v in tokens.items() if v}
    if not compact:
        return None
    return encode_token({"sources": compact})


def extract_tokens(token: Optional[str]) -> Dict[str, str]:
    if not token:
        return {}
    payload = decode_token(token)
    sources = payload.get("sources", {})
    return {k: v for k, v in sources.items() if isinstance(v, str)}
