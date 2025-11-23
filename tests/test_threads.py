import time

import httpx


def _delayed_json(payload, etag):
    def handler(request):
        time.sleep(0.25)
        return httpx.Response(200, json=payload, headers={"ETag": etag})

    return handler


def test_parallel_fanout(client, respx_mock):
    respx_mock.get("https://users.service.test/users/u-1").mock(
        side_effect=_delayed_json({"id": "u-1", "tier": "VIP"}, '"u-etag"')
    )
    respx_mock.get("https://catalog.service.test/items/i-1").mock(
        side_effect=_delayed_json({"id": "i-1", "name": "Couture"}, '"i-etag"')
    )
    respx_mock.get(
        "https://catalog.service.test/items/i-1/availability"
    ).mock(return_value=httpx.Response(200, json={"available": True}))
    respx_mock.post("https://orders.service.test/orders").mock(
        return_value=httpx.Response(
            201, json={"id": "order-123", "status": "pending"}, headers={"ETag": '"o"'}
        )
    )

    resp = client.post(
        "/orders",
        json={
            "userId": "u-1",
            "itemId": "i-1",
            "startDate": "2024-08-01",
            "endDate": "2024-08-05",
        },
    )

    assert resp.status_code == 201
    assert resp.headers["X-Composite-Threaded"] == "true"
    parallel_ms = int(resp.headers["X-Composite-Parallel-Ms"])
    assert parallel_ms < 400, f"fan-out took too long: {parallel_ms}ms"
