# Table: gitlab_project_tag

The `gitlab_project_tag` table can be used to query information about repository tags for a specific project.

However, **you must specify** a `project_id` in the where or join clause.

## Examples

### List all tags for a project

```sql
select
  name,
  target,
  message,
  protected,
  created_at
from
  gitlab_project_tag
where
  project_id = 123;
```

### List tags for all projects in a group

```sql
select
  p.name as project_name,
  t.name as tag,
  t.target
from
  gitlab_group_project p
  join gitlab_project_tag t on t.project_id = p.id
where
  p.group_id = 1234;
```

### List only protected tags for a project

```sql
select
  name,
  target
from
  gitlab_project_tag
where
  project_id = 123
  and protected = true;
```
