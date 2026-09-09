-- Cascade deletes for strictly-owned child rows
--
-- Rationale:
--   task_subtasks and notes_listitems are strictly-owned children. A subtask
--   cannot meaningfully exist without its parent task, and a list item cannot
--   exist without its parent note. When the parent is deleted, the children
--   MUST be removed too, otherwise they become orphaned rows that no client
--   ever cleans up.
--
--   Previously the client deleted children explicitly (only on the shared/direct
--   path) and relied on nothing for the offline path, which leaked orphans. With
--   a local-first sync layer (Legend-State) uploading plain row deletes, the
--   correct place to enforce this invariant is the database via ON DELETE CASCADE.
--   Deleting the parent locally uploads a single delete; Postgres cascades to the
--   children; those deletions then replicate back down to every client.
--
-- Deliberately NOT changed:
--   notes.projectID -> task_projects.recordID
--   tasks.projectID -> task_projects.recordID
--   Projects are OPTIONAL parents. A note or task can validly stand alone, so
--   these FKs remain nullable with NO cascade. Deleting a project must not
--   delete the notes/tasks within it (they simply become project-less).
--
-- This migration is idempotent: it only re-creates a constraint as CASCADE when
-- the current constraint is not already ON DELETE CASCADE.

-- =============================================================================
-- task_subtasks.taskID -> tasks.recordID  (ON DELETE CASCADE)
-- =============================================================================

DO $$
BEGIN
  -- Only act if the FK exists and is not already ON DELETE CASCADE.
  -- confdeltype 'c' = CASCADE in pg_constraint.
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'task_subtasks_taskID_fkey'
      AND confdeltype <> 'c'
  ) THEN
    ALTER TABLE public.task_subtasks
      DROP CONSTRAINT "task_subtasks_taskID_fkey";
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'task_subtasks_taskID_fkey'
  ) THEN
    ALTER TABLE public.task_subtasks
      ADD CONSTRAINT "task_subtasks_taskID_fkey"
      FOREIGN KEY ("taskID") REFERENCES public.tasks("recordID")
      ON DELETE CASCADE;
  END IF;
END $$;

-- =============================================================================
-- notes_listitems.noteID -> notes.recordID  (ON DELETE CASCADE)
-- =============================================================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'notes_listitems_noteID_fkey'
      AND confdeltype <> 'c'
  ) THEN
    ALTER TABLE public.notes_listitems
      DROP CONSTRAINT "notes_listitems_noteID_fkey";
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'notes_listitems_noteID_fkey'
  ) THEN
    ALTER TABLE public.notes_listitems
      ADD CONSTRAINT "notes_listitems_noteID_fkey"
      FOREIGN KEY ("noteID") REFERENCES public.notes("recordID")
      ON DELETE CASCADE;
  END IF;
END $$;
