UPDATE workspace_members
SET role = 'OPERATOR'
WHERE role IS NULL
   OR TRIM(role) = ''
   OR UPPER(TRIM(role)) = 'MEMBER'
   OR UPPER(TRIM(role)) NOT IN ('OWNER', 'MAINTAINER', 'OPERATOR', 'VIEWER');

CREATE INDEX IF NOT EXISTS idx_workspace_members_role
    ON workspace_members(workspace_id, role);

-- Legal roles may still be stored in another case or padded with whitespace.
-- Two owner predicates disagree on such rows: a strict `role = 'OWNER'` misses
-- them while `UPPER(TRIM(role))` counts them, which would let the last-owner
-- guard act on an inflated count. Canonicalize so both agree.
UPDATE workspace_members
SET role = UPPER(TRIM(role))
WHERE role IS NOT NULL
  AND TRIM(role) <> ''
  AND UPPER(TRIM(role)) IN ('OWNER', 'MAINTAINER', 'OPERATOR', 'VIEWER')
  AND role <> UPPER(TRIM(role));
