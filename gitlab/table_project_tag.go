package gitlab

import (
	"context"
	"fmt"
	"github.com/turbot/steampipe-plugin-sdk/v5/grpc/proto"
	"github.com/turbot/steampipe-plugin-sdk/v5/plugin"
	"github.com/turbot/steampipe-plugin-sdk/v5/plugin/transform"
	api "gitlab.com/gitlab-org/api/client-go/v2"
)

func tableProjectTag() *plugin.Table {
	return &plugin.Table{
		Name:        "gitlab_project_tag",
		Description: "Obtain information about repository tags for a specific project.",
		List: &plugin.ListConfig{
			KeyColumns: plugin.SingleColumn("project_id"),
			Hydrate:    listProjectTags,
		},
		Columns: projectTagColumns(),
	}
}

func listProjectTags(ctx context.Context, d *plugin.QueryData, h *plugin.HydrateData) (interface{}, error) {
	plugin.Logger(ctx).Debug("listProjectTags", "started")
	conn, err := connect(ctx, d)
	if err != nil {
		plugin.Logger(ctx).Error("listProjectTags", "unable to establish a connection", err)
		return nil, fmt.Errorf("unable to establish a connection: %v", err)
	}

	projectId := int(d.EqualsQuals["project_id"].GetInt64Value())
	orderBy := "version"
	sort := "desc"
	opt := &api.ListTagsOptions{
		OrderBy: &orderBy,
		Sort:    &sort,
		ListOptions: api.ListOptions{
			Page:    1,
			PerPage: 50,
		},
	}

	for {
		plugin.Logger(ctx).Debug("listProjectTags", "projectId", projectId, "page", opt.Page, "perPage", opt.PerPage)
		tags, resp, err := conn.Tags.ListTags(projectId, opt)
		if err != nil {
			plugin.Logger(ctx).Error("listProjectTags", "projectId", projectId, "page", opt.Page, "error", err)
			return nil, fmt.Errorf("unable to obtain tags for project_id %d\n%v", projectId, err)
		}

		for _, tag := range tags {
			d.StreamListItem(ctx, tag)
			if d.RowsRemaining(ctx) == 0 {
				plugin.Logger(ctx).Debug("listProjectTags", "completed successfully")
				return nil, nil
			}
		}

		if resp.NextPage == 0 {
			break
		}

		opt.Page = resp.NextPage
	}

	plugin.Logger(ctx).Debug("listProjectTags", "completed successfully")
	return nil, nil
}

func projectTagColumns() []*plugin.Column {
	return []*plugin.Column{
		{
			Name:        "project_id",
			Type:        proto.ColumnType_INT,
			Description: "The ID of the project - link to `gitlab_project.id`.",
			Transform:   transform.FromQual("project_id"),
		},
		{
			Name:        "name",
			Type:        proto.ColumnType_STRING,
			Description: "The name of the tag.",
		},
		{
			Name:        "message",
			Type:        proto.ColumnType_STRING,
			Description: "The message associated with the tag.",
		},
		{
			Name:        "target",
			Type:        proto.ColumnType_STRING,
			Description: "The commit SHA the tag points to.",
		},
		{
			Name:        "protected",
			Type:        proto.ColumnType_BOOL,
			Description: "Indicates if the tag is protected.",
		},
		{
			Name:        "created_at",
			Type:        proto.ColumnType_TIMESTAMP,
			Description: "Timestamp when the tag was created.",
		},
	}
}
