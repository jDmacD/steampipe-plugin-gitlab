#!/usr/bin/env bash
# Smoke-test every gitlab_* steampipe table.
# Runs against whichever instance .steampipe/config/gitlab.spc is pointing at.
# Uses glab for fixture discovery.
#
# Env vars:
#   GITLAB_ADDR        API base URL of the instance to test (default: gitlab.com)
#   GITLAB_TOKEN       access token (overrides .steampipe/config/gitlab.spc)
#   GITLAB_TEST_GROUP  path of the test group (default: steampipe-gitlab-testing)
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
INSTALL_DIR="$REPO_ROOT/.steampipe"
SP="steampipe --install-dir $INSTALL_DIR query"
TEST_GROUP="${GITLAB_TEST_GROUP:-steampipe-gitlab-testing}"

PASS=0; FAIL=0; SKIP=0

ok()   { echo "  PASS  $1"; PASS=$(( PASS + 1 )); }
fail() { echo "  FAIL  $1  ($2)"; FAIL=$(( FAIL + 1 )); }
skip() { echo "  SKIP  $1  ($2)"; SKIP=$(( SKIP + 1 )); }

# Run a steampipe query; succeed on exit 0, fail otherwise.
# Empty result sets are fine — we are testing that the query doesn't error.
q() { $SP "$1" --output json > /dev/null 2>&1; }

run() {
    local table="$1" sql="$2"
    if q "$sql"; then ok "$table"; else fail "$table" "query error"; fi
}

# ---------------------------------------------------------------------------
# Detect instance from GITLAB_ADDR env var (mirrors what the plugin reads)
# ---------------------------------------------------------------------------
if [[ -n "${GITLAB_ADDR:-}" ]]; then
    GITLAB_HOST=$(echo "$GITLAB_ADDR" | sed 's|https\?://||' | sed 's|/api/v4.*||' | sed 's|/$||')
else
    GITLAB_HOST="gitlab.com"
fi

IS_SAAS=false
[[ "$GITLAB_HOST" == "gitlab.com" ]] && IS_SAAS=true

echo "Instance : $GITLAB_HOST"
echo "SaaS     : $IS_SAAS"
echo "Group    : $TEST_GROUP"
echo ""

# ---------------------------------------------------------------------------
# Resolve fixtures via glab
# ---------------------------------------------------------------------------
echo "Resolving fixtures..."

api() { glab api "$1" --hostname "$GITLAB_HOST"; }

USER_ID=$(api /user | jq -r '.id')
USERNAME=$(api /user | jq -r '.username')

GROUP_RESP=$(api "groups/$TEST_GROUP" 2>&1) || {
    echo "Error: group '$TEST_GROUP' not found on $GITLAB_HOST."
    echo "Create it or set GITLAB_TEST_GROUP."
    exit 1
}
GROUP_ID=$(echo "$GROUP_RESP" | jq -r '.id')

PROJECTS=$(api "groups/$TEST_GROUP/projects?per_page=1")
PROJECT_ID=$(echo "$PROJECTS" | jq -r '.[0].id // empty')
PROJECT_PATH=$(echo "$PROJECTS" | jq -r '.[0].path_with_namespace // empty')

if [[ -z "$PROJECT_ID" ]]; then
    echo "Error: no projects found in $TEST_GROUP. Create at least one project."
    exit 1
fi

DEFAULT_BRANCH=$(api "projects/$PROJECT_ID" | jq -r '.default_branch // "main"')

echo "  user     : $USERNAME (id=$USER_ID)"
echo "  group    : $TEST_GROUP (id=$GROUP_ID)"
echo "  project  : $PROJECT_PATH (id=$PROJECT_ID, branch=$DEFAULT_BRANCH)"
echo "  tag      : ${TAG_NAME:-(none)}"

# Optional fixtures — resolved now, used to skip tests gracefully
COMMIT_SHA=$(api "projects/$PROJECT_ID/repository/commits?per_page=1" | jq -r '.[0].id // empty')
PIPELINE_ID=$(api "projects/$PROJECT_ID/pipelines?per_page=1" | jq -r '.[0].id // empty')
MR_IID=$(api "projects/$PROJECT_ID/merge_requests?per_page=1" | jq -r '.[0].iid // empty')
TAG_NAME=$(api "projects/$PROJECT_ID/repository/tags?per_page=1" | jq -r '.[0].name // empty')

echo ""
echo "Running table tests..."
echo ""

# ---------------------------------------------------------------------------
# Tables with no required qualifiers
# ---------------------------------------------------------------------------
run gitlab_my_project "SELECT * FROM gitlab_my_project LIMIT 1"
run gitlab_my_issue   "SELECT * FROM gitlab_my_issue LIMIT 1"
run gitlab_my_event   "SELECT * FROM gitlab_my_event LIMIT 1"
run gitlab_version    "SELECT * FROM gitlab_version LIMIT 1"
run gitlab_snippet    "SELECT * FROM gitlab_snippet LIMIT 1"

# ---------------------------------------------------------------------------
# User tables
# ---------------------------------------------------------------------------
run gitlab_user       "SELECT * FROM gitlab_user WHERE username = '$USERNAME'"
run gitlab_user_event "SELECT * FROM gitlab_user_event WHERE author_id = $USER_ID LIMIT 1"

# ---------------------------------------------------------------------------
# Project table (uses id= qualifier on SaaS)
# ---------------------------------------------------------------------------
run gitlab_project "SELECT * FROM gitlab_project WHERE id = $PROJECT_ID LIMIT 1"

# ---------------------------------------------------------------------------
# Group-scoped tables
# ---------------------------------------------------------------------------
run gitlab_group                "SELECT * FROM gitlab_group WHERE id = $GROUP_ID"
run gitlab_group_member         "SELECT * FROM gitlab_group_member WHERE group_id = $GROUP_ID LIMIT 1"
run gitlab_group_project        "SELECT * FROM gitlab_group_project WHERE group_id = $GROUP_ID LIMIT 1"
run gitlab_group_subgroup       "SELECT * FROM gitlab_group_subgroup WHERE parent_id = $GROUP_ID LIMIT 1"
run gitlab_group_hook           "SELECT * FROM gitlab_group_hook WHERE group_id = $GROUP_ID LIMIT 1"
run gitlab_group_variable       "SELECT * FROM gitlab_group_variable WHERE group_id = $GROUP_ID LIMIT 1"
run gitlab_group_access_request "SELECT * FROM gitlab_group_access_request WHERE group_id = $GROUP_ID LIMIT 1"

# ---------------------------------------------------------------------------
# Project-scoped tables
# ---------------------------------------------------------------------------
run gitlab_branch                  "SELECT * FROM gitlab_branch WHERE project_id = $PROJECT_ID LIMIT 1"
run gitlab_issue                   "SELECT * FROM gitlab_issue WHERE project_id = $PROJECT_ID LIMIT 1"
run gitlab_merge_request           "SELECT * FROM gitlab_merge_request WHERE project_id = $PROJECT_ID LIMIT 1"
run gitlab_project_member          "SELECT * FROM gitlab_project_member WHERE project_id = $PROJECT_ID LIMIT 1"
run gitlab_project_variable        "SELECT * FROM gitlab_project_variable WHERE project_id = $PROJECT_ID LIMIT 1"
run gitlab_project_pipeline        "SELECT * FROM gitlab_project_pipeline WHERE project_id = $PROJECT_ID LIMIT 1"
run gitlab_project_protected_branch "SELECT * FROM gitlab_project_protected_branch WHERE project_id = $PROJECT_ID LIMIT 1"
run gitlab_project_repository      "SELECT * FROM gitlab_project_repository WHERE project_id = $PROJECT_ID LIMIT 1"
run gitlab_project_job             "SELECT * FROM gitlab_project_job WHERE project_id = $PROJECT_ID LIMIT 1"
run gitlab_project_deployment      "SELECT * FROM gitlab_project_deployment WHERE project_id = $PROJECT_ID LIMIT 1"
run gitlab_project_container_registry "SELECT * FROM gitlab_project_container_registry WHERE project_id = $PROJECT_ID LIMIT 1"
run gitlab_project_pages_domain    "SELECT * FROM gitlab_project_pages_domain WHERE project_id = $PROJECT_ID LIMIT 1"
run gitlab_project_access_request  "SELECT * FROM gitlab_project_access_request WHERE project_id = $PROJECT_ID LIMIT 1"

# ---------------------------------------------------------------------------
# Tables that need a repository tag to exist
# ---------------------------------------------------------------------------
if [[ -n "$TAG_NAME" ]]; then
    run gitlab_project_tag \
        "SELECT * FROM gitlab_project_tag WHERE project_id = $PROJECT_ID LIMIT 1"
else
    skip gitlab_project_tag "no tags in test project"
fi

# ---------------------------------------------------------------------------
# Tables that need a commit to exist
# ---------------------------------------------------------------------------
if [[ -n "$COMMIT_SHA" ]]; then
    run gitlab_commit \
        "SELECT * FROM gitlab_commit WHERE project_id = $PROJECT_ID LIMIT 1"
    run gitlab_project_repository_file \
        "SELECT * FROM gitlab_project_repository_file WHERE project_id = $PROJECT_ID AND file_path = 'README.md' AND ref = '$DEFAULT_BRANCH'"
else
    skip gitlab_commit               "no commits in test project"
    skip gitlab_project_repository_file "no commits in test project"
fi

# ---------------------------------------------------------------------------
# Tables that need a pipeline
# ---------------------------------------------------------------------------
if [[ -n "$PIPELINE_ID" ]]; then
    run gitlab_project_pipeline_detail \
        "SELECT * FROM gitlab_project_pipeline_detail WHERE project_id = $PROJECT_ID AND id = $PIPELINE_ID"
else
    skip gitlab_project_pipeline_detail "no pipelines in test project"
fi

# ---------------------------------------------------------------------------
# Tables that need a merge request
# ---------------------------------------------------------------------------
if [[ -n "$MR_IID" ]]; then
    run gitlab_merge_request_change \
        "SELECT * FROM gitlab_merge_request_change WHERE project_id = $PROJECT_ID AND iid = $MR_IID LIMIT 1"
else
    skip gitlab_merge_request_change "no merge requests in test project"
fi

# ---------------------------------------------------------------------------
# Admin-only tables (skip on SaaS)
# ---------------------------------------------------------------------------
if [[ "$IS_SAAS" == "false" ]]; then
    run gitlab_application      "SELECT * FROM gitlab_application LIMIT 1"
    run gitlab_setting          "SELECT * FROM gitlab_setting LIMIT 1"
    run gitlab_instance_variable "SELECT * FROM gitlab_instance_variable LIMIT 1"
else
    skip gitlab_application      "admin-only, not available on gitlab.com"
    skip gitlab_setting          "admin-only, not available on gitlab.com"
    skip gitlab_instance_variable "admin-only, not available on gitlab.com"
fi

# ---------------------------------------------------------------------------
# EE-only tables (skip on SaaS free tier)
# ---------------------------------------------------------------------------
if [[ "$IS_SAAS" == "false" ]]; then
    run gitlab_epic              "SELECT * FROM gitlab_epic WHERE group_id = $GROUP_ID LIMIT 1"
    run gitlab_group_iteration   "SELECT * FROM gitlab_group_iteration WHERE group_id = $GROUP_ID LIMIT 1"
    run gitlab_group_push_rule   "SELECT * FROM gitlab_group_push_rule WHERE group_id = $GROUP_ID LIMIT 1"
    run gitlab_project_iteration "SELECT * FROM gitlab_project_iteration WHERE project_id = $PROJECT_ID LIMIT 1"
else
    skip gitlab_epic              "EE-only, not available on free gitlab.com"
    skip gitlab_group_iteration   "EE-only, not available on free gitlab.com"
    skip gitlab_group_push_rule   "EE-only, not available on free gitlab.com"
    skip gitlab_project_iteration "EE-only, not available on free gitlab.com"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
