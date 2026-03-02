---
name: databricks-bundle-validate
description: Analyze Databricks Bundles and their resources, validate changes with databricks bundle validate
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: databricks
---

## What I do

- Analyze Databricks Bundle configurations (databricks.yml) and their resources
- Understand the structure of bundles including: targets, resources (jobs, pipelines, notebooks), variables, and dependencies
- Validate bundle changes by running `databricks bundle validate`
- Help troubleshoot bundle configuration issues

## When to use me

Use this when working with Databricks Bundle projects. Ask me to:
- Explain the bundle structure and resources
- Analyze specific bundle configurations
- Validate changes after modifications

## How to work with me

1. First, explore the bundle structure using glob and read tools
2. Look for `databricks.yml` or `resources/*` files
3. After making any changes, always run `databricks bundle validate` to verify correctness

## Validation command

Always execute this after bundle modifications:
```
databricks bundle validate
```

If validation fails, analyze the errors and help fix the configuration issues.