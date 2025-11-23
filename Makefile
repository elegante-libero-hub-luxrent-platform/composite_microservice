.PHONY: dev run test docker-build docker-run

dev:
	uvicorn app:app --host 0.0.0.0 --port $${PORT:-8080} --reload

run:
	uvicorn app:app --host 0.0.0.0 --port $${PORT:-8080}

test:
	pytest -q

docker-build:
	docker build -t composite:latest .

docker-run:
	docker run --rm -p 8080:8080 -e USER_SVC_BASE -e CAT_SVC_BASE -e ORD_SVC_BASE composite:latest
