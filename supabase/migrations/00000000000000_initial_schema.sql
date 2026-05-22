-- Initial schema migration for SimpleBudget
-- Creates all tables, foreign keys, RLS policies, and required roles

-- =============================================================================
-- Roles (required for PostgREST and GoTrue)
-- =============================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator NOINHERIT LOGIN;
  END IF;
END
$$;

GRANT anon TO authenticator;
GRANT authenticated TO authenticator;
GRANT service_role TO authenticator;

-- =============================================================================
-- Note: auth schema, auth.users table, and auth.uid() function are provided
-- by the supabase/postgres image. No need to create them here.
-- =============================================================================

-- =============================================================================
-- Tables
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.users (
  "recordID" uuid NOT NULL PRIMARY KEY,
  "fullName" character varying NOT NULL,
  "userType" character varying NOT NULL
);

CREATE TABLE IF NOT EXISTS public.budgets (
  "recordID" character varying NOT NULL PRIMARY KEY,
  "creatorID" uuid NOT NULL,
  "budgetName" character varying
);

CREATE TABLE IF NOT EXISTS public.sections (
  "recordID" character varying NOT NULL PRIMARY KEY,
  "sectionName" character varying NOT NULL,
  "budgetID" character varying NOT NULL,
  "sectionType" character varying NOT NULL,
  "sectionYear" numeric NOT NULL,
  "sectionMonth" character varying NOT NULL
);

CREATE TABLE IF NOT EXISTS public.categories (
  "recordID" character varying NOT NULL PRIMARY KEY,
  "sectionID" character varying NOT NULL,
  "categoryName" character varying NOT NULL,
  "amount" numeric NOT NULL,
  "categoryNote" text
);

CREATE TABLE IF NOT EXISTS public.shared (
  "recordID" character varying NOT NULL PRIMARY KEY,
  "budgetID" character varying NOT NULL,
  "sharedToID" uuid NOT NULL
);

CREATE TABLE IF NOT EXISTS public.transactions (
  "recordID" character varying NOT NULL PRIMARY KEY,
  "budgetID" character varying NOT NULL,
  "categoryID" character varying,
  "amount" numeric NOT NULL,
  "title" character varying NOT NULL,
  "transactionType" character varying NOT NULL,
  "creatorID" uuid,
  "transactionDate" numeric NOT NULL
);

-- =============================================================================
-- Foreign Keys
-- =============================================================================

ALTER TABLE public.budgets
  ADD CONSTRAINT "budgets_creatorID_fkey"
  FOREIGN KEY ("creatorID") REFERENCES public.users("recordID");

ALTER TABLE public.sections
  ADD CONSTRAINT "sections_budgetID_fkey"
  FOREIGN KEY ("budgetID") REFERENCES public.budgets("recordID");

ALTER TABLE public.categories
  ADD CONSTRAINT "categories_sectionID_fkey"
  FOREIGN KEY ("sectionID") REFERENCES public.sections("recordID");

ALTER TABLE public.shared
  ADD CONSTRAINT "shared_budgetID_fkey"
  FOREIGN KEY ("budgetID") REFERENCES public.budgets("recordID");

ALTER TABLE public.shared
  ADD CONSTRAINT "shared_sharedToID_fkey"
  FOREIGN KEY ("sharedToID") REFERENCES public.users("recordID");

ALTER TABLE public.transactions
  ADD CONSTRAINT "transactions_budgetID_fkey"
  FOREIGN KEY ("budgetID") REFERENCES public.budgets("recordID");

ALTER TABLE public.transactions
  ADD CONSTRAINT "transactions_creatorID_fkey"
  FOREIGN KEY ("creatorID") REFERENCES public.users("recordID");

ALTER TABLE public.transactions
  ADD CONSTRAINT "transactions_categoryID_fkey"
  FOREIGN KEY ("categoryID") REFERENCES public.categories("recordID");

-- =============================================================================
-- Enable Row Level Security
-- =============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- RLS Policies: users
-- =============================================================================

CREATE POLICY "INSERT -> authenticated"
  ON public.users FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "SELECT -> authenticated"
  ON public.users FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "UPDATE -> creator"
  ON public.users FOR UPDATE
  TO authenticated
  USING (auth.uid() = "recordID")
  WITH CHECK (auth.uid() = "recordID");

-- =============================================================================
-- RLS Policies: budgets
-- =============================================================================

CREATE POLICY "SELECT -> authenticated ./"
  ON public.budgets FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "INSERT -> authenticated ./"
  ON public.budgets FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "UPDATE -> creators + authenticated ./"
  ON public.budgets FOR UPDATE
  TO authenticated
  USING (auth.uid() = "creatorID")
  WITH CHECK (auth.uid() = "creatorID");

CREATE POLICY "DELETE -> creators + authenticated ./"
  ON public.budgets FOR DELETE
  TO authenticated
  USING (auth.uid() = "creatorID");

-- =============================================================================
-- RLS Policies: sections
-- =============================================================================

CREATE POLICY "ALL - creator/shared + authenticated ./"
  ON public.sections FOR ALL
  TO authenticated
  USING (
    (auth.uid() IN (
      SELECT budgets."creatorID"
      FROM budgets
      WHERE (sections."budgetID")::text = (sections."budgetID")::text
    ))
    OR
    (auth.uid() IN (
      SELECT shared."sharedToID"
      FROM shared
      WHERE (shared."budgetID")::text = (shared."budgetID")::text
    ))
  )
  WITH CHECK (
    (auth.uid() IN (
      SELECT budgets."creatorID"
      FROM budgets
      WHERE (sections."budgetID")::text = (sections."budgetID")::text
    ))
    OR
    (auth.uid() IN (
      SELECT shared."sharedToID"
      FROM shared
      WHERE (shared."budgetID")::text = (shared."budgetID")::text
    ))
  );

-- =============================================================================
-- RLS Policies: categories
-- =============================================================================

CREATE POLICY "ALL - creator/shared + authenticated ./"
  ON public.categories FOR ALL
  TO authenticated
  USING (
    (auth.uid() IN (
      SELECT budgets."creatorID"
      FROM budgets
      WHERE (budgets."recordID")::text IN (
        SELECT sections."budgetID"
        FROM sections
        WHERE (sections."recordID")::text = (categories."sectionID")::text
      )
    ))
    OR
    (auth.uid() IN (
      SELECT shared."sharedToID"
      FROM shared
      WHERE (shared."budgetID")::text IN (
        SELECT sections."budgetID"
        FROM sections
        WHERE (sections."recordID")::text = (categories."sectionID")::text
      )
    ))
  )
  WITH CHECK (
    (auth.uid() IN (
      SELECT budgets."creatorID"
      FROM budgets
      WHERE (budgets."recordID")::text IN (
        SELECT sections."budgetID"
        FROM sections
        WHERE (sections."recordID")::text = (categories."sectionID")::text
      )
    ))
    OR
    (auth.uid() IN (
      SELECT shared."sharedToID"
      FROM shared
      WHERE (shared."budgetID")::text IN (
        SELECT sections."budgetID"
        FROM sections
        WHERE (sections."recordID")::text = (categories."sectionID")::text
      )
    ))
  );

-- =============================================================================
-- RLS Policies: shared
-- =============================================================================

CREATE POLICY "SELECT -> authenticated"
  ON public.shared FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "INSERT -> creator + authenticated"
  ON public.shared FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() IN (
      SELECT budgets."creatorID"
      FROM budgets
      WHERE (budgets."recordID")::text = (shared."budgetID")::text
    )
  );

CREATE POLICY "UPDATE -> creator + authenticated"
  ON public.shared FOR UPDATE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT budgets."creatorID"
      FROM budgets
      WHERE (budgets."recordID")::text = (shared."budgetID")::text
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT budgets."creatorID"
      FROM budgets
      WHERE (budgets."recordID")::text = (shared."budgetID")::text
    )
  );

CREATE POLICY "DELETE -> creator + authenticated"
  ON public.shared FOR DELETE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT budgets."creatorID"
      FROM budgets
      WHERE (budgets."recordID")::text = (shared."budgetID")::text
    )
  );

-- =============================================================================
-- RLS Policies: transactions
-- =============================================================================

CREATE POLICY "ALL -> creator/shared + authenticated ./"
  ON public.transactions FOR ALL
  TO authenticated
  USING (
    (auth.uid() IN (
      SELECT budgets."creatorID"
      FROM budgets
      WHERE (budgets."recordID")::text = (transactions."budgetID")::text
    ))
    OR
    (auth.uid() IN (
      SELECT shared."sharedToID"
      FROM shared
      WHERE (shared."budgetID")::text = (shared."budgetID")::text
    ))
  )
  WITH CHECK (
    (auth.uid() IN (
      SELECT budgets."creatorID"
      FROM budgets
      WHERE (budgets."recordID")::text = (transactions."budgetID")::text
    ))
    OR
    (auth.uid() IN (
      SELECT shared."sharedToID"
      FROM shared
      WHERE (shared."budgetID")::text = (shared."budgetID")::text
    ))
  );

-- =============================================================================
-- Grant permissions to roles
-- =============================================================================

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;
