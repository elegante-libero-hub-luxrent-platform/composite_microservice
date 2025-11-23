import httpx


def _mock_user(respx_mock, status=200):
    respx_mock.get("https://users.service.test/users/u-404").mock(
        return_value=httpx.Response(status, json={"id": "u-404"})
    )


def test_missing_user_returns_422(client, respx_mock):
    respx_mock.get("https://users.service.test/users/u-404").mock(
        return_value=httpx.Response(404)
    )
    respx_mock.get("https://catalog.service.test/items/i-1").mock(
        return_value=httpx.Response(200, json={"id": "i-1"})
    )

    resp = client.post(
        "/orders",
        json={"userId": "u-404", "itemId": "i-1"},
    )

    assert resp.status_code == 422
    assert resp.json()["detail"]["code"] == "FK_USER_NOT_FOUND"


def test_missing_item_returns_422(client, respx_mock):
    respx_mock.get("https://users.service.test/users/u-1").mock(
        return_value=httpx.Response(200, json={"id": "u-1"})
    )
    respx_mock.get("https://catalog.service.test/items/i-404").mock(
        return_value=httpx.Response(404)
    )

    resp = client.post(
        "/orders",
        json={"userId": "u-1", "itemId": "i-404"},
    )

    assert resp.status_code == 422
    assert resp.json()["detail"]["code"] == "FK_ITEM_NOT_FOUND"


def test_unavailable_item_returns_409(client, respx_mock):
    respx_mock.get("https://users.service.test/users/u-1").mock(
        return_value=httpx.Response(200, json={"id": "u-1"})
    )
    respx_mock.get("https://catalog.service.test/items/i-1").mock(
        return_value=httpx.Response(200, json={"id": "i-1"})
    )
    respx_mock.get(
        "https://catalog.service.test/items/i-1/availability"
    ).mock(return_value=httpx.Response(409, json={"code": "NOT_AVAILABLE"}))

    resp = client.post(
        "/orders",
        json={
            "userId": "u-1",
            "itemId": "i-1",
            "startDate": "2024-09-01",
            "endDate": "2024-09-05",
        },
    )

    assert resp.status_code == 409
    assert resp.json()["detail"]["code"] == "ITEM_UNAVAILABLE"
