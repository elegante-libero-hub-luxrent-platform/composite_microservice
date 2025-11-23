from pagination import (
    decode_token,
    encode_token,
    extract_tokens,
    merge_tokens,
)


def test_merge_tokens_filters_empty():
    token = merge_tokens({"items": "abc", "orders": None})
    decoded = decode_token(token)
    assert decoded["sources"] == {"items": "abc"}


def test_extract_tokens_round_trip():
    payload = {"sources": {"items": "a", "orders": "b"}}
    token = encode_token(payload)
    assert extract_tokens(token) == payload["sources"]
