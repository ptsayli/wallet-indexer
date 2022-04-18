-- Up Migration

CREATE TYPE "order_kind_t" AS ENUM (
  'wyvern-v2',
  'wyvern-v2.3',
  'looks-rare',
  'opendao-erc721',
  'opendao-erc1155',
  'zeroex-v4-erc721',
  'zeroex-v4-erc1155'
);

CREATE TYPE "order_side_t" AS ENUM (
  'buy',
  'sell'
);

CREATE TYPE "order_fillability_status_t" AS ENUM (
  'fillable',
  'no-balance',
  'cancelled',
  'filled',
  'expired'
);

CREATE TYPE "order_approval_status_t" AS ENUM (
  'approved',
  'no-approval',
  'disabled'
);

CREATE TABLE "orders" (
  "id" TEXT NOT NULL,
  "kind" "order_kind_t" NOT NULL,
  "side" "order_side_t",
  "fillability_status" "order_fillability_status_t",
  "approval_status" "order_approval_status_t",
  "token_set_id" TEXT,
  "token_set_schema_hash" BYTEA,
  "maker" BYTEA,
  "taker" BYTEA,
  "price" NUMERIC(78, 0),
  "value" NUMERIC(78, 0),
  "quantity_filled" NUMERIC(78, 0) DEFAULT 0,
  "quantity_remaining" NUMERIC(78, 0) DEFAULT 1,
  "valid_between" TSTZRANGE,
  "nonce" NUMERIC(78, 0),
  "source_id" BYTEA,
  "source_id_int" INT,
  "contract" BYTEA,
  "fee_bps" INT,
  "fee_breakdown" JSONB,
  "dynamic" BOOLEAN,
  "raw_data" JSONB,
  "expiration" TIMESTAMPTZ,
  "created_at" TIMESTAMPTZ DEFAULT now(),
  "updated_at" TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE "orders"
  ADD CONSTRAINT "orders_pk"
  PRIMARY KEY ("id");

CREATE INDEX "orders_token_set_id_side_value_maker_index"
  ON "orders" ("token_set_id", "side", "value", "maker")
  INCLUDE ("id")
  WHERE ("fillability_status" = 'fillable' AND "approval_status" = 'approved');

CREATE INDEX "orders_maker_side_token_set_id_index"
  ON "orders" ("maker", "side", "token_set_id")
  INCLUDE ("id")
  WHERE ("fillability_status" = 'fillable' OR "fillability_status" = 'no-balance');

CREATE INDEX "orders_upper_valid_between_index"
  ON "orders" (UPPER("valid_between"))
  INCLUDE ("id")
  WHERE ("fillability_status" = 'fillable' OR "fillability_status" = 'no-balance');

CREATE INDEX "orders_kind_maker_nonce_index"
  ON "orders" ("kind", "maker", "nonce")
  WHERE ("fillability_status" = 'fillable' OR "fillability_status" = 'no-balance');

CREATE INDEX "orders_side_created_at_index"
  ON "orders" ("side", "created_at" DESC)
  WHERE ("contract" IS NOT NULL);

CREATE INDEX "orders_side_contract_created_at_index"
  ON "orders" ("side", "contract", "created_at" DESC)
  WHERE ("contract" IS NOT NULL);

CREATE INDEX "orders_side_source_created_at_index"
  ON "orders" ("side", coalesce("source_id", '\x00'), "created_at" DESC)
  WHERE ("contract" IS NOT NULL);

CREATE INDEX "orders_expired_maker_side_created_at_id_index"
  ON "orders" ("maker", "side", "created_at" DESC, "id" DESC)
  WHERE ("fillability_status" != 'fillable' AND "fillability_status" != 'no-balance' AND "maker" IS NOT NULL);

CREATE INDEX "orders_not_expired_maker_side_created_at_id_index"
  ON "orders" ("maker", "side", "created_at" DESC, "id" DESC)
  INCLUDE ("approval_status")
  WHERE ("fillability_status" = 'fillable' OR "fillability_status" = 'no-balance');

CREATE INDEX "orders_dynamic_index"
  ON "orders" ("id")
  WHERE ("dynamic" AND ("fillability_status" = 'fillable' OR "fillability_status" = 'no-balance'));

-- https://www.lob.com/blog/supercharge-your-postgresql-performance
-- https://klotzandrew.com/blog/posgres-per-table-autovacuum-management
ALTER TABLE "orders" SET (autovacuum_vacuum_scale_factor = 0.0);
ALTER TABLE "orders" SET (autovacuum_vacuum_threshold = 5000);
ALTER TABLE "orders" SET (autovacuum_analyze_scale_factor = 0.0);
ALTER TABLE "orders" SET (autovacuum_analyze_threshold = 5000);

-- Down Migration

DROP TABLE "orders";

DROP TYPE "order_approval_status_t";

DROP TYPE "order_fillability_status_t";

DROP TYPE "order_side_t";

DROP TYPE "order_kind_t";