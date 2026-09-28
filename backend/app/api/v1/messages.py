import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user
from app.db.session import get_db
from app.models.listing import Listing
from app.models.message import Conversation, Message
from app.models.user import User
from app.schemas.message import ConversationCreate, ConversationOut, ConversationSummaryOut, MessageCreate, MessageOut

router = APIRouter(prefix="/messages", tags=["messages"])


@router.get("/conversations", response_model=list[ConversationSummaryOut])
async def list_conversations(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[ConversationSummaryOut]:
    result = await db.execute(
        select(Conversation)
        .where((Conversation.guest_id == current_user.id) | (Conversation.host_id == current_user.id))
        .order_by(Conversation.updated_at.desc())
    )
    conversations = list(result.scalars().all())

    summaries: list[ConversationSummaryOut] = []
    for conversation in conversations:
        other_user_id = conversation.host_id if conversation.guest_id == current_user.id else conversation.guest_id
        other_user_result = await db.execute(select(User).where(User.id == other_user_id))
        other_user = other_user_result.scalar_one_or_none()

        last_message_result = await db.execute(
            select(Message)
            .where(Message.conversation_id == conversation.id)
            .order_by(Message.created_at.desc())
            .limit(1)
        )
        last_message = last_message_result.scalar_one_or_none()

        summaries.append(
            ConversationSummaryOut(
                id=conversation.id,
                listing_id=conversation.listing_id,
                other_user_name=other_user.full_name if other_user else "Unknown user",
                other_user_avatar_url=other_user.avatar_url if other_user else None,
                last_message_body=last_message.body if last_message else None,
                last_message_at=last_message.created_at if last_message else None,
                created_at=conversation.created_at,
            )
        )
    return summaries


@router.post("/conversations", response_model=ConversationOut, status_code=status.HTTP_201_CREATED)
async def start_conversation(
    payload: ConversationCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Conversation:
    listing_result = await db.execute(select(Listing).where(Listing.id == payload.listing_id))
    listing = listing_result.scalar_one_or_none()
    if not listing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Listing not found")

    existing = await db.execute(
        select(Conversation).where(
            Conversation.listing_id == listing.id,
            Conversation.guest_id == current_user.id,
            Conversation.host_id == listing.host_id,
        )
    )
    conversation = existing.scalar_one_or_none()
    if conversation:
        return conversation

    conversation = Conversation(listing_id=listing.id, guest_id=current_user.id, host_id=listing.host_id)
    db.add(conversation)
    await db.commit()
    await db.refresh(conversation)
    return conversation


async def _get_conversation_or_403(conversation_id: uuid.UUID, current_user: User, db: AsyncSession) -> Conversation:
    result = await db.execute(select(Conversation).where(Conversation.id == conversation_id))
    conversation = result.scalar_one_or_none()
    if not conversation:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
    if current_user.id not in (conversation.guest_id, conversation.host_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not part of this conversation")
    return conversation


@router.get("/conversations/{conversation_id}/messages", response_model=list[MessageOut])
async def list_messages(
    conversation_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[Message]:
    await _get_conversation_or_403(conversation_id, current_user, db)
    result = await db.execute(
        select(Message).where(Message.conversation_id == conversation_id).order_by(Message.created_at)
    )
    return list(result.scalars().all())


@router.post("/conversations/{conversation_id}/messages", response_model=MessageOut, status_code=status.HTTP_201_CREATED)
async def send_message(
    conversation_id: uuid.UUID,
    payload: MessageCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Message:
    from app.api.v1.ws import manager

    conversation = await _get_conversation_or_403(conversation_id, current_user, db)
    message = Message(conversation_id=conversation.id, sender_id=current_user.id, body=payload.body, image_url=payload.image_url)
    db.add(message)
    await db.commit()
    await db.refresh(message)

    await manager.broadcast(conversation_id, MessageOut.model_validate(message).model_dump(mode="json"))
    return message
