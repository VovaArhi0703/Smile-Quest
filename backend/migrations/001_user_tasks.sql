BEGIN;

CREATE TABLE IF NOT EXISTS user_tasks (
  user_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  task_id text NOT NULL,
  task_data jsonb,
  created_order bigint GENERATED ALWAYS AS IDENTITY,
  deleted_at timestamptz,
  PRIMARY KEY (user_id, task_id),
  CHECK ((deleted_at IS NULL) = (task_data IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS user_tasks_live_order_idx
  ON user_tasks (user_id, created_order) WHERE deleted_at IS NULL;

COMMIT;
