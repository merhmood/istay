import uuid
from collections import defaultdict

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy import select

from app.core.security import decode_token
from app.db.session import AsyncSessionLocal
from app.models.message import Conversation
from app.models.user import User

router = APIRouter(tags=["messages"])


class ConnectionManager:
    def __init__(self) -> None:
        self._connections: dict[uuid.UUID, set[WebSocket]] = defaultdict(set)

    async def connect(self, conversation_id: uuid.UUID, websocket: WebSocket) -> None:
        await websocket.accept()
        self._connections[conversation_id].add(websocket)

    def disconnect(self, conversation_id: uuid.UUID, websocket: WebSocket) -> None:
        self._connections[conversation_id].discard(websocket)

    async def broadcast(self, conversation_id: uuid.UUID, payload: dict) -> None:
        for ws in list(self._connections.get(conversation_id, set())):
            try:
                await ws.send_json(payload)
            except Exception:
                self.disconnect(conversation_id, ws)


manager = ConnectionManager()


@router.websocket("/ws/conversations/{conversation_id}")
async def conversation_socket(websocket: WebSocket, conversation_id: uuid.UUID, token: str) -> None:
    """Live chat feed. Client connects with ?token=<access_token> and receives every new
    message sent to this conversation via REST POST /messages/conversations/{id}/messages
    (sending happens over REST so the same code path validates and persists every message;
    this socket is push-only)."""
    try:
        user_id = decode_token(token, "access")
    except Exception:
        await websocket.close(code=4401)
        return

    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            await websocket.close(code=4401)
            return

        conv_result = await db.execute(select(Conversation).where(Conversation.id == conversation_id))
        conversation = conv_result.scalar_one_or_none()
        if not conversation or user.id not in (conversation.guest_id, conversation.host_id):
            await websocket.close(code=4403)
            return

    await manager.connect(conversation_id, websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(conversation_id, websocket)
