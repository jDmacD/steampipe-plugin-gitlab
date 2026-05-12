package gitlab

import (
	"context"
	"testing"
)

func TestPluginName(t *testing.T) {
	p := Plugin(context.Background())
	if p.Name != "steampipe-plugin-gitlab" {
		t.Errorf("plugin name = %q; want %q", p.Name, "steampipe-plugin-gitlab")
	}
}

func TestPluginTableMap(t *testing.T) {
	p := Plugin(context.Background())

	expected := []string{
		"gitlab_application",
		"gitlab_branch",
		"gitlab_commit",
		"gitlab_epic",
		"gitlab_group",
		"gitlab_group_access_request",
		"gitlab_group_hook",
		"gitlab_group_iteration",
		"gitlab_group_member",
		"gitlab_group_project",
		"gitlab_group_push_rule",
		"gitlab_group_subgroup",
		"gitlab_group_variable",
		"gitlab_instance_variable",
		"gitlab_issue",
		"gitlab_merge_request",
		"gitlab_merge_request_change",
		"gitlab_my_event",
		"gitlab_my_issue",
		"gitlab_my_project",
		"gitlab_project",
		"gitlab_project_access_request",
		"gitlab_project_container_registry",
		"gitlab_project_deployment",
		"gitlab_project_iteration",
		"gitlab_project_job",
		"gitlab_project_member",
		"gitlab_project_pages_domain",
		"gitlab_project_pipeline",
		"gitlab_project_pipeline_detail",
		"gitlab_project_protected_branch",
		"gitlab_project_repository",
		"gitlab_project_repository_file",
		"gitlab_project_variable",
		"gitlab_setting",
		"gitlab_snippet",
		"gitlab_user",
		"gitlab_user_event",
		"gitlab_version",
	}

	for _, name := range expected {
		if _, ok := p.TableMap[name]; !ok {
			t.Errorf("plugin TableMap missing table %q", name)
		}
	}

	if got, want := len(p.TableMap), len(expected); got != want {
		t.Errorf("plugin has %d tables; want %d", got, want)
	}
}

func TestPluginTableColumns(t *testing.T) {
	p := Plugin(context.Background())

	for name, table := range p.TableMap {
		if table == nil {
			t.Errorf("table %q is nil", name)
			continue
		}
		if table.Name != name {
			t.Errorf("table registered as %q but table.Name = %q", name, table.Name)
		}
		if len(table.Columns) == 0 {
			t.Errorf("table %q has no columns", name)
		}
		if table.List == nil && table.Get == nil {
			t.Errorf("table %q has neither List nor Get hydrate config", name)
		}
	}
}
