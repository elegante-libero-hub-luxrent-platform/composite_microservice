import httpx

from pagination import decode_token


def test_user_etag_passthrough(client, respx_mock):
    respx_mock.get("https://users.service.test/users/u-42").mock(
        return_value=httpx.Response(
            200, json={"id": "u-42"}, headers={"ETag": '"user-etag"'}
        )
    )

    resp = client.get("/users/u-42")
    assert resp.status_code == 200
    assert resp.headers["ETag"] == '"user-etag"'


def test_user_etag_304(client, respx_mock):
    respx_mock.get("https://users.service.test/users/u-42").mock(
        return_value=httpx.Response(304)
    )

    resp = client.get("/users/u-42", headers={"If-None-Match": '"user-etag"'})
    assert resp.status_code == 304


def test_combined_etag_on_search(client, respx_mock):
    respx_mock.get("https://catalog.service.test/items").mock(
        return_value=httpx.Response(
            200,
            json={"items": [{"id": "i-1"}], "nextPageToken": "i-more"},
            headers={"ETag": '"i-etag"'},
        )
    )
    respx_mock.get("https://orders.service.test/orders").mock(
        return_value=httpx.Response(
            200,
            json={"orders": [{"id": "o-1"}], "nextPageToken": "o-more"},
            headers={"ETag": '"o-etag"'},
        )
    )

    resp = client.get("/search?q=dress&pageSize=5")
    assert resp.status_code == 200
    assert resp.headers["ETag"].startswith('"')
    token = resp.json()["nextPageToken"]
    decoded = decode_token(token)
    assert decoded["sources"]["items"] == "i-more"
    assert decoded["sources"]["orders"] == "o-more"
