# Table: gitlab_group_project

The `gitlab_group_project`  table will obtain information from all projects associated to the group (& it's sub-groups).

However, **you must specify** a `group_id` in the where or join clause.

## Examples

### List all projects for a group and its subgroups

```sql
select
  id,
  name,
  full_path,
  description,
  default_branch,
  public,
  visibility,
  archived.
  web_url
from
  gitlab_group_project
where
  group_id = 1234;
```

### List repository tags for all projects in a group

Use `gitlab_project_tag` to query repository tags per project. The `tag_list` column on this table reflects project topics (GitLab settings), not git tags.

```sql
select
  p.name as project_name,
  t.name as tag
from
  gitlab_group_project p
  join gitlab_project_tag t on t.project_id = p.id
where
  p.group_id = 1234;
```

### List all projects for a specific group only

```sql
select
  id,
  name,
  full_path,
  description,
  default_branch,
  public,
  visibility,
  archived.
  web_url
from
  gitlab_group_project
where
  group_id = 1234
and
  namespace_id = 1234;
```
