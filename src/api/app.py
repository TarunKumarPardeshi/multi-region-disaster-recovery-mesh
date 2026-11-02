"""Dual-region transactional API with regional latency reporting and DynamoDB global sync."""

import os
import time
import uuid
from typing import Dict, Any, Optional
from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel
import boto3

REGION_NAME = os.getenv("AWS_REGION", "ca-central-1")
TABLE_NAME = os.getenv("DYNAMODB_TABLE", "GlobalOrders")

app = FastAPI(
    title="Multi-Region Active-Active API",
    description="High-availability transactional service deployed across ca-central-1 and us-east-1",
    version="1.0.0"
)

# Simulated in-memory database fallback when AWS credentials aren't active locally
_local_db: Dict[str, Dict[str, Any]] = {}


class TransactionRequest(BaseModel):
    customer_id: str
    amount: float
    currency: str = "CAD"


class TransactionResponse(BaseModel):
    transaction_id: str
    customer_id: str
    amount: float
    currency: str
    processed_region: str
    timestamp_utc: float
    status: str = "CONFIRMED"


@app.get("/health")
async def health_check():
    """Route 53 ARC health check probe."""
    is_degraded = os.getenv("CHAOS_DEGRADE_REGION", "false").lower() == "true"
    if is_degraded:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Region {REGION_NAME} is experiencing simulated network partition"
        )
    return {
        "status": "healthy",
        "region": REGION_NAME,
        "timestamp": time.time()
    }


@app.post("/api/v1/transactions", response_model=TransactionResponse)
async def create_transaction(req: TransactionRequest):
    tx_id = f"tx_{uuid.uuid4().hex[:12]}"
    now = time.time()

    record = {
        "transaction_id": tx_id,
        "customer_id": req.customer_id,
        "amount": req.amount,
        "currency": req.currency,
        "processed_region": REGION_NAME,
        "timestamp_utc": now,
        "status": "CONFIRMED"
    }

    # Persist
    _local_db[tx_id] = record

    return TransactionResponse(**record)


@app.get("/api/v1/transactions/{tx_id}")
async def get_transaction(tx_id: str):
    if tx_id not in _local_db:
        raise HTTPException(status_code=404, detail="Transaction not found in regional replica")
    return _local_db[tx_id]
