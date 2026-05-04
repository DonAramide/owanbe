-- Audit + transition rules for vendor_applications.status (requires 003_vendor_onboarding.sql).
-- App should set actor for each transaction: SELECT set_config('owanbe.actor_user_id', '<uuid>', true);
-- (third arg true = transaction-local). If unset, actor_user_id in events is NULL.

BEGIN;

CREATE OR REPLACE FUNCTION owanbe_session_actor_user_id()
RETURNS UUID
LANGUAGE plpgsql
STABLE AS $$
DECLARE
  raw TEXT;
BEGIN
  BEGIN
    raw := current_setting('owanbe.actor_user_id', true);
  EXCEPTION
    WHEN undefined_object THEN
      RETURN NULL;
  END;
  IF raw IS NULL OR btrim(raw) = '' THEN
    RETURN NULL;
  END IF;
  RETURN raw::uuid;
EXCEPTION
  WHEN invalid_text_representation THEN
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION owanbe_vendor_application_status_transition_chk()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status IS DISTINCT FROM 'applied'::vendor_application_status THEN
      RAISE EXCEPTION 'vendor_applications must be created with status applied (got %)', NEW.status;
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
      RETURN NEW;
    END IF;
    IF OLD.status IN ('approved', 'rejected') THEN
      RAISE EXCEPTION 'vendor_applications status is terminal (%); create a new application to resubmit', OLD.status;
    END IF;
    IF OLD.status = 'applied'::vendor_application_status
       AND NEW.status NOT IN ('under_review', 'rejected') THEN
      RAISE EXCEPTION 'invalid transition applied -> %', NEW.status;
    END IF;
    IF OLD.status = 'under_review'::vendor_application_status
       AND NEW.status NOT IN ('approved', 'rejected', 'applied') THEN
      RAISE EXCEPTION 'invalid transition under_review -> %', NEW.status;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER vendor_applications_status_transition_chk
BEFORE INSERT OR UPDATE OF status ON vendor_applications
FOR EACH ROW
EXECUTE PROCEDURE owanbe_vendor_application_status_transition_chk();

CREATE OR REPLACE FUNCTION owanbe_vendor_application_status_audit()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
  v_from vendor_application_status;
  v_to vendor_application_status;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_from := NULL;
    v_to := NEW.status;
    INSERT INTO vendor_application_events (application_id, actor_user_id, from_status, to_status, note, metadata)
    VALUES (
      NEW.id,
      owanbe_session_actor_user_id(),
      v_from,
      v_to,
      'insert',
      '{}'::JSONB
    );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO vendor_application_events (application_id, actor_user_id, from_status, to_status, note, metadata)
    VALUES (
      NEW.id,
      owanbe_session_actor_user_id(),
      OLD.status,
      NEW.status,
      NULL,
      '{}'::JSONB
    );
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER vendor_applications_status_audit
AFTER INSERT OR UPDATE OF status ON vendor_applications
FOR EACH ROW
EXECUTE PROCEDURE owanbe_vendor_application_status_audit();

COMMIT;
