-- Migration: 044_ai_negotiation_engine.sql
-- Create custom type enums if they do not exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'negotiation_session_state') THEN
    CREATE TYPE negotiation_session_state AS ENUM (
      'created',
      'open',
      'negotiating',
      'counter_offer',
      'waiting_vendor_confirmation',
      'waiting_organizer_confirmation',
      'agreed',
      'payment_pending',
      'payment_received',
      'escrowed',
      'work_started',
      'completed',
      'closed'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'risk_score_level') THEN
    CREATE TYPE risk_score_level AS ENUM ('low', 'medium', 'high');
  END IF;
END
$$;

-- Sessions Table
CREATE TABLE IF NOT EXISTS negotiation_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  event_id UUID NOT NULL,
  vendor_id UUID NOT NULL REFERENCES vendors (id) ON DELETE RESTRICT,
  organizer_id UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  state negotiation_session_state NOT NULL DEFAULT 'created',
  risk_score risk_score_level NOT NULL DEFAULT 'low',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Message Audit Logs
CREATE TABLE IF NOT EXISTS negotiation_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES negotiation_sessions (id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  receiver_id UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  message_text TEXT NOT NULL,
  original_text TEXT,
  read_status TEXT NOT NULL DEFAULT 'delivered',
  read_at TIMESTAMPTZ,
  device_details TEXT,
  ip_address TEXT,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Versioned Offers
CREATE TABLE IF NOT EXISTS negotiation_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES negotiation_sessions (id) ON DELETE CASCADE,
  offer_number INT NOT NULL,
  amount_minor BIGINT NOT NULL,
  proposed_by UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- User confirmations logs
CREATE TABLE IF NOT EXISTS negotiation_confirmations (
  session_id UUID NOT NULL REFERENCES negotiation_sessions (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  confirmed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (session_id, user_id)
);

-- Cryptographic Contracts & Signatures
CREATE TABLE IF NOT EXISTS negotiation_contracts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES negotiation_sessions (id) ON DELETE CASCADE,
  contract_hash TEXT NOT NULL,
  terms TEXT NOT NULL,
  vendor_signature TEXT,
  organizer_signature TEXT,
  pdf_uri TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Escrow Payments & Virtual Accounts
CREATE TABLE IF NOT EXISTS negotiation_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES negotiation_sessions (id) ON DELETE CASCADE,
  virtual_account_number TEXT NOT NULL,
  bank_name TEXT NOT NULL,
  escrow_status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- AI Fraud scans & confidence score records
CREATE TABLE IF NOT EXISTS negotiation_ai_analysis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES negotiation_sessions (id) ON DELETE CASCADE,
  confidence_score INT NOT NULL,
  reasons JSONB NOT NULL DEFAULT '[]'::jsonb,
  flagged_fraud BOOLEAN NOT NULL DEFAULT FALSE,
  fraud_reasons JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
