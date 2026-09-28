"""full-text and trigram search support for listings

Adds two complementary search mechanisms:

* a GIN index over an English tsvector of title/city/landmark/description, which
  handles word-level matching with stemming ("apartments" matches "apartment");
* pg_trgm indexes, which handle the misspellings full-text search cannot -
  "leki" still finds "Lekki", which matters when guests type place names from
  memory.

Revision ID: 0003_search_indexes
Revises: 0002_favorites
Create Date: 2026-09-22
"""
from typing import Sequence, Union

from alembic import op

revision: str = "0003_search_indexes"
down_revision: Union[str, None] = "0002_favorites"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Weighted so a hit in the title or city outranks one buried in the description.
# A/B/C/D are Postgres' built-in weight classes, ranked highest to lowest.
SEARCH_VECTOR = """
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(city, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(neighborhood_landmark, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(property_type, '')), 'C') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'D')
"""


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    op.execute(
        f"CREATE INDEX ix_listings_search_vector ON listings USING GIN (({SEARCH_VECTOR.strip()}))"
    )
    # Trigram indexes power similarity() for fuzzy matching on the fields guests
    # actually type: a place name or a listing title.
    op.execute("CREATE INDEX ix_listings_city_trgm ON listings USING GIN (city gin_trgm_ops)")
    op.execute("CREATE INDEX ix_listings_title_trgm ON listings USING GIN (title gin_trgm_ops)")
    op.execute(
        "CREATE INDEX ix_listings_landmark_trgm ON listings USING GIN (neighborhood_landmark gin_trgm_ops)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_listings_landmark_trgm")
    op.execute("DROP INDEX IF EXISTS ix_listings_title_trgm")
    op.execute("DROP INDEX IF EXISTS ix_listings_city_trgm")
    op.execute("DROP INDEX IF EXISTS ix_listings_search_vector")
    # Extension left in place: other objects may come to depend on it.
