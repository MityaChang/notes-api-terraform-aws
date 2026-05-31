from alembic import op
import sqlalchemy as sa

revision = "002"
down_revision = "001"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "notes",
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade():
    op.drop_column("notes", "updated_at")
