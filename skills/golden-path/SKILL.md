---
name: golden-path
description: Load before building, changing, or deploying any web app, API, function, or database on Firebase / Google Cloud. Covers the four edges of production (platform, delivery, security, observability) for builders who are new to running software.
---

# Golden path: managed serverless (Firebase / Google Cloud)

You are helping someone who may never have run software in production. They know
what the business needs; they don't know what production needs. Your job is to
cover the gap without being asked. Apply every section below on every task, and
explain each choice in one plain-language sentence.

Before you finish any task, walk the **Done checklist** at the bottom.

## Platform

Run on managed services. Never a raw VM.

- Static site and front end: **Firebase Hosting**.
- Server-side code: **Cloud Run functions** (2nd gen) or **Cloud Run**. These scale to zero, so idle cost is close to nothing.
- Data: **Firestore**. Users and sign-in: **Firebase Authentication**.
- Do not create Compute Engine VMs, self-managed databases, or anything the
  builder would have to patch. If a request seems to need one, stop and explain
  the trade-off before proceeding.
- Keep everything in one Firebase / Google Cloud project per environment
  (for example `myapp-dev` and `myapp-prod`). Never test against prod data.

## Delivery

Ship through a pull request. Never deploy from a laptop.

- All changes go on a new branch and open a GitHub pull request.
- CI (GitHub Actions) runs on every PR: install, lint, test, build, and a
  `firebase hosting:channel:deploy` to a **preview channel** for the front end.
- Production deploys happen only from `main`, only from CI, after the PR merges.
- CI authenticates to Google Cloud with **Workload Identity Federation**, not a
  downloaded service account key.
- If the builder asks you to "just deploy it", open the PR and explain why.

## Security

Assume the builder will paste secrets and leave doors open. Don't let them.

- **Never accept a secret in chat.** If one appears, tell the builder to rotate
  it now, then store the new value in **Secret Manager**. Do not write it to a
  file, a commit, an `.env` that is tracked, or a log.
- Functions read secrets from Secret Manager at runtime (for example
  `defineSecret()` in Cloud Functions for Firebase).
- **Firestore and Storage security rules are default-deny.** Grant the minimum
  access per collection. Never ship `allow read, write: if true;`.
- **Every HTTP endpoint checks auth** (verify the Firebase ID token) unless it is
  deliberately public. Public endpoints validate input and are rate-limited or
  protected with App Check.
- Validate and sanitize all input from forms and webhooks.
- Grant service accounts the smallest IAM role that works. No `Owner` or
  `Editor` on runtime identities.
- Add `.env*`, keys, and credential files to `.gitignore` before the first commit.

## Observability

The builder should know the site is down before a customer calls.

- Every public URL and form endpoint gets a **Cloud Monitoring uptime check**.
- An **alert policy** emails (or texts) the builder when an uptime check fails
  or the function error rate spikes.
- Functions log with structured logging; errors surface in **Error Reporting**.
- Set a **budget alert** on the billing account so a runaway bill is caught early.

## Done checklist

A task is not done until each item is true or explicitly waived by the builder:

- [ ] Runs on managed services only; no VMs.
- [ ] Change is on a branch with an open PR; CI is green.
- [ ] No secrets in code, chat, or logs; runtime secrets come from Secret Manager.
- [ ] Database and storage rules are default-deny; endpoints check auth.
- [ ] New or changed endpoints have an uptime check and an alert.
- [ ] You told the builder, in plain words, what you set up and why.
