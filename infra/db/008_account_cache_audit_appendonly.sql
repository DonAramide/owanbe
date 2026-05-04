-- Final hardening: roles cache versioning, user banned status, append-only audit_log.
-- Apply after 007_roles_hardening_audit.sql

BEGIN;

-- ---------------------------------------------------------------------------
-- user_status: add banned (idempotent for re-runs)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  ALTER TYPE user_status ADD VALUE 'banned';
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END;
$$;

-- ---------------------------------------------------------------------------
-- roles_version: any user_roles or user.status change bumps cache generation
-- ---------------------------------------------------------------------------
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS roles_version BIGINT NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION owanbe_user_roles_bump_roles_version()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
  uid UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    uid := OLD.user_id;
  ELSE
    uid := NEW.user_id;
  END IF;
  UPDATE users SET roles_version = roles_version + 1, updated_at = now() WHERE id = uid;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS user_roles_bump_roles_version ON user_roles;
CREATE TRIGGER user_roles_bump_roles_version
AFTER INSERT OR UPDATE OR DELETE ON user_roles
FOR EACH ROW
EXECUTE PROCEDURE owanbe_user_roles_bump_roles_version();

CREATE OR REPLACE FUNCTION owanbe_users_bump_roles_version_on_status()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.roles_version := COALESCE(OLD.roles_version, 0) + 1;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS users_status_bump_roles_version ON users;
CREATE TRIGGER users_status_bump_roles_version
BEFORE UPDATE OF status ON users
FOR EACH ROW
EXECUTE PROCEDURE owanbe_users_bump_roles_version_on_status();

-- ---------------------------------------------------------------------------
-- audit_log append-only
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION owanbe_audit_log_append_only()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'audit_log rows are append-only (no UPDATE or DELETE)';
END;
$$;

DROP TRIGGER IF EXISTS audit_log_block_update ON audit_log;
CREATE TRIGGER audit_log_block_update
BEFORE UPDATE ON audit_log
FOR EACH ROW
EXECUTE PROCEDURE owanbe_audit_log_append_only();

DROP TRIGGER IF EXISTS audit_log_block_delete ON audit_log;
CREATE TRIGGER audit_log_block_delete
BEFORE DELETE ON audit_log
FOR EACH ROW
EXECUTE PROCEDURE owanbe_audit_log_append_only();

COMMIT;
