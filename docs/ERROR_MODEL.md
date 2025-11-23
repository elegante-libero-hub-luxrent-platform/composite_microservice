# Error Model

The composite service uses a single error envelope with `code`, `message`, optional `details`, and `traceId`.

- `404 NOT_FOUND` – surface when delegated services indicate missing resources.
- `409 CONFLICT` – returned for item availability conflicts and order confirmation failures.
- `422 FK_*` – logical foreign key enforcement before an order is created.
