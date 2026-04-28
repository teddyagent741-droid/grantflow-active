"""add compliance summary to grant applications

Revision ID: 6f7ab9f228c1
Revises: 4db3f73ae1fd
Create Date: 2026-04-21 23:30:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "6f7ab9f228c1"
down_revision: str | None = "4db3f73ae1fd"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("grant_applications", sa.Column("compliance_summary", sa.JSON(), nullable=True))


def downgrade() -> None:
    op.drop_column("grant_applications", "compliance_summary")
