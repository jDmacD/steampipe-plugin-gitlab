connection "gitlab" {
  plugin = "local/gitlab"

  # Base URL of your GitLab instance API.
  # Omit for gitlab.com. Can also be set via the GITLAB_ADDR env var.
  # baseurl = "https://gitlab.yourcompany.com/api/v4"

  # Personal or project access token.
  # Can also be set via the GITLAB_TOKEN env var.
  # token = "glpat-xxxxxxxxxxxxxxxxxxxx"
}