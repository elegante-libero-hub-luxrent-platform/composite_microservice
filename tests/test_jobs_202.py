import httpx


def test_confirm_order_returns_202(client, respx_mock):
    respx_mock.post("https://orders.service.test/orders/order-9/confirm").mock(
        return_value=httpx.Response(
            202, json={"jobId": "job-9"}, headers={"Location": "/jobs/job-9"}
        )
    )

    resp = client.post("/orders/order-9/confirm")
    assert resp.status_code == 202
    assert resp.headers["Location"] == "/jobs/job-9"
    assert resp.json()["jobId"] == "job-9"


def test_job_polling_happy_path(client, respx_mock):
    respx_mock.get("https://orders.service.test/jobs/job-9").mock(
        return_value=httpx.Response(
            200, json={"jobId": "job-9", "status": "SUCCEEDED", "result": {"id": 1}}
        )
    )

    resp = client.get("/jobs/job-9")
    assert resp.status_code == 200
    assert resp.json()["status"] == "SUCCEEDED"
