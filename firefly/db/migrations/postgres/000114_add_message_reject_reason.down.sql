BEGIN;
ALTER TABLE messages DROP COLUMN reject_reason;
COMMIT;
