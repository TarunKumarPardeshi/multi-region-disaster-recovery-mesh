import pytest
from fastapi.testclient import TestClient
from src.api.app import app
from src.chaos.failover_orchestrator import FailoverOrchestrator

client = TestClient(app)


def test_health_check_nominal():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "healthy"


def test_transaction_creation():
    payload = {"customer_id": "cust_toronto_01", "amount": 149.99, "currency": "CAD"}
    resp = client.post("/api/v1/transactions", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert data["customer_id"] == "cust_toronto_01"
    assert data["amount"] == 149.99
    assert data["status"] == "CONFIRMED"


def test_failover_orchestrator_initial_state():
    orch = FailoverOrchestrator(primary_region="ca-central-1", secondary_region="us-east-1")
    status = orch.get_routing_status()
    assert status["ca-central-1"] == "On"
    assert status["us-east-1"] == "Off"


def test_failover_execution_and_rto_benchmark():
    orch = FailoverOrchestrator(primary_region="ca-central-1", secondary_region="us-east-1")
    result = orch.trigger_failover("Chaos Test Outage Drill")
    assert result["status"] == "FAILOVER_COMPLETE"
    assert result["active_region"] == "us-east-1"
    assert result["drained_region"] == "ca-central-1"
    assert result["measured_rto_seconds"] < 30.0  # Must be strictly under 30s SLA
    assert result["data_loss_records"] == 0  # Zero data loss
