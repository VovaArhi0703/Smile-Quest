CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  full_name text NOT NULL DEFAULT '',
  avatar_url text NOT NULL DEFAULT 'assets/avatars/avatar_1.png',
  pet_name text NOT NULL DEFAULT '',
  pet_age text NOT NULL DEFAULT '',
  coins integer NOT NULL DEFAULT 0 CHECK (coins >= 0),
  xp integer NOT NULL DEFAULT 0 CHECK (xp >= 0),
  level integer NOT NULL DEFAULT 1 CHECK (level >= 1),
  login_streak integer NOT NULL DEFAULT 0,
  login_count integer NOT NULL DEFAULT 0,
  last_login_date date,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE sessions (
  token_hash text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL
);
CREATE INDEX sessions_user_id_idx ON sessions(user_id);
CREATE TABLE login_days (
  user_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  day date NOT NULL,
  PRIMARY KEY (user_id, day)
);
CREATE TABLE user_progress (
  user_id uuid PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
  values_json jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE TABLE user_achievements (
  user_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  achievement_id text NOT NULL,
  unlocked_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, achievement_id)
);
CREATE TABLE users_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  file_name text NOT NULL,
  section text NOT NULL,
  exercise text NOT NULL,
  date_taken timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX photos_user_date_idx ON users_photos(user_id, date_taken DESC);
CREATE TABLE reward_events (
  user_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  event_key text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, event_key)
);
CREATE TABLE user_tasks (
  user_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  task_id text NOT NULL,
  task_data jsonb,
  created_order bigint GENERATED ALWAYS AS IDENTITY,
  deleted_at timestamptz,
  PRIMARY KEY (user_id, task_id),
  CHECK ((deleted_at IS NULL) = (task_data IS NOT NULL))
);
CREATE INDEX user_tasks_live_order_idx
  ON user_tasks (user_id, created_order) WHERE deleted_at IS NULL;
