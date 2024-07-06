#!/bin/bash

# Define the GitHub token and organization name
GITHUB_TOKEN={{github_pat}}
ORG="antrein"

# Update config_be_mode variable
curl -L \
  -X PATCH \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/orgs/$ORG/actions/variables/config_be_mode" \
  -d "{\"name\":\"CONFIG_BE_MODE\",\"value\":\"$be_mode\",\"visibility\":\"all\"}"

# Update config_infra_mode variable
curl -L \
  -X PATCH \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/orgs/$ORG/actions/variables/config_infra_mode" \
  -d "{\"name\":\"CONFIG_INFRA_MODE\",\"value\":\"$infra_mode\",\"visibility\":\"all\"}"
