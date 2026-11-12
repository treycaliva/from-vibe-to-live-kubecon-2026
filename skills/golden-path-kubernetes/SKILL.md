---
name: golden-path-kubernetes
description: Load before building, changing, or deploying any service to the internal Kubernetes platform. Covers the four edges of production (platform, delivery, security, observability) using the platform team's approved CNCF tooling.
---

# Golden path: internal Kubernetes platform

This is a template. A platform team should fork it and replace every
`<placeholder>` with its real values: template names, repo URLs, cluster names,
and policy names. The structure is the same four edges as the managed
serverless skill. Only the tools change.

You are helping a builder who may not know Kubernetes. Apply every section on
every task, prefer the platform's paved road over anything custom, and explain
each choice in one plain-language sentence. Walk the **Done checklist** before
finishing.

## Platform

Start from a template. Never hand-roll a cluster resource the platform provides.

- New services start from a **Backstage software template**
  (`<template-name>`) so they get the standard repo layout, catalog entry,
  ownership, and pipeline.
- HTTP services that can scale to zero run as a **Knative Service**. Long-running
  or stateful workloads use the platform's standard `Deployment` chart
  (`<chart-name>`).
- Deploy only to the namespaces the service owns. Never create cluster-scoped
  resources, `ClusterRole`s, or CRDs.
- Set CPU and memory requests and limits on every container.

## Delivery

Git is the only way into the cluster.

- All changes go through a pull request to the service repo and, for
  environment config, to the GitOps repo (`<gitops-repo>`).
- **Argo CD** or **Flux** reconciles the cluster from Git. Never run
  `kubectl apply`, `kubectl edit`, or `helm install` against a shared cluster.
- CI builds images with **Cloud Native Buildpacks** (or the platform's
  Dockerfile template), signs them, and pushes to `<registry>`.
- Promotion between environments is a PR that bumps the image tag in the
  GitOps repo.

## Security

Admission policy is the backstop. Don't make it work hard.

- **Never accept a secret in chat** or commit one to Git. Secrets live in
  `<secret-store>` and reach the cluster through the **External Secrets
  Operator** (`ExternalSecret` resources only).
- Manifests must pass the platform's **Kyverno** or **OPA Gatekeeper**
  policies: non-root, read-only root filesystem, no privileged containers,
  no `hostPath`, images only from `<registry>`.
- Every service gets a `NetworkPolicy` that is default-deny, opening only the
  ports and peers it needs.
- Workloads use a dedicated `ServiceAccount` with the least RBAC that works.
- Use the cluster's workload identity for cloud access, never long-lived keys.

## Observability

The owner should know it's broken before a user does.

- Instrument with **OpenTelemetry** (traces, metrics, logs) and export to the
  platform collector (`<otel-endpoint>`).
- Expose metrics for **Prometheus**; add a `ServiceMonitor` or `PodMonitor`.
- Every user-facing service defines an SLO and an alert routed to its owning
  team (`<alert-route>`).
- Readiness and liveness probes on every container.

## Read-only cluster access (MCP)

If a Kubernetes MCP server is available, use it to **read** cluster state
(pods, events, logs) when debugging. It should be configured read-only and
backed by a view-only RBAC role. Changes still go through Git.

## Done checklist

- [ ] Service came from (or matches) the Backstage template; catalog entry and owner set.
- [ ] Change is a PR; Argo CD / Flux will apply it. No direct `kubectl` changes.
- [ ] No secrets in Git or chat; secrets come through External Secrets.
- [ ] Manifests pass Kyverno / Gatekeeper; NetworkPolicy and least-privilege RBAC in place.
- [ ] OpenTelemetry, Prometheus scraping, probes, and an SLO alert are configured.
- [ ] You told the builder, in plain words, what you set up and why.
