package gitlab

import (
	"context"
	"testing"
	"time"

	"github.com/turbot/steampipe-plugin-sdk/v5/plugin/transform"
	api "gitlab.com/gitlab-org/api/client-go"
)

func TestParseAccessLevel(t *testing.T) {
	tests := []struct {
		input int
		want  string
	}{
		{0, "No Permissions"},
		{5, "Minimal Access"},
		{10, "Guest"},
		{20, "Reporter"},
		{30, "Developer"},
		{40, "Maintainer"},
		{50, "Owner"},
		{99, "No Permissions"}, // unknown value falls through to default
	}
	for _, tt := range tests {
		got := parseAccessLevel(tt.input)
		if got != tt.want {
			t.Errorf("parseAccessLevel(%d) = %q; want %q", tt.input, got, tt.want)
		}
	}
}

func TestAccessLevelTransform(t *testing.T) {
	tests := []struct {
		name  string
		value *api.AccessLevelValue
		want  string
	}{
		{"NoPermissions", accessLevel(api.NoPermissions), "No Permissions"},
		{"MinimalAccess", accessLevel(api.MinimalAccessPermissions), "Minimal Access"},
		{"Guest", accessLevel(api.GuestPermissions), "Guest"},
		{"Reporter", accessLevel(api.ReporterPermissions), "Reporter"},
		{"Developer", accessLevel(api.DeveloperPermissions), "Developer"},
		{"Maintainer", accessLevel(api.MaintainerPermissions), "Maintainer"},
		{"Owner", accessLevel(api.OwnerPermissions), "Owner"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := accessLevelTransform(context.Background(), &transform.TransformData{Value: tt.value})
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != tt.want {
				t.Errorf("accessLevelTransform(%v) = %q; want %q", *tt.value, got, tt.want)
			}
		})
	}

	t.Run("nil", func(t *testing.T) {
		got, err := accessLevelTransform(context.Background(), &transform.TransformData{Value: nil})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if got != nil {
			t.Errorf("accessLevelTransform(nil) = %v; want nil", got)
		}
	})
}

func TestIsoTimeTransform(t *testing.T) {
	t.Run("nil", func(t *testing.T) {
		got, err := isoTimeTransform(context.Background(), &transform.TransformData{Value: nil})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if got != nil {
			t.Errorf("isoTimeTransform(nil) = %v; want nil", got)
		}
	})

	t.Run("valid date", func(t *testing.T) {
		iso := api.ISOTime(time.Date(2024, 3, 15, 0, 0, 0, 0, time.UTC))
		got, err := isoTimeTransform(context.Background(), &transform.TransformData{Value: &iso})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		result, ok := got.(time.Time)
		if !ok {
			t.Fatalf("expected time.Time, got %T", got)
		}
		if result.Year() != 2024 || result.Month() != 3 || result.Day() != 15 {
			t.Errorf("isoTimeTransform returned %v; want 2024-03-15", result)
		}
	})
}

func accessLevel(v api.AccessLevelValue) *api.AccessLevelValue {
	return &v
}
