package main

import (
	"context"
	"testing"

	"github.com/theapsgroup/steampipe-plugin-gitlab/gitlab"
)

func TestPluginLoads(t *testing.T) {
	p := gitlab.Plugin(context.Background())
	if p == nil {
		t.Fatal("Plugin() returned nil")
	}
}
