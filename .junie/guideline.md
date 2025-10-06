
# Project Guidelines (central deployment; Compose + NixOS; nested profiles; Website UI)

**Audience:** advanced developers.

**Goal:** a central control‑plane bootstraps OS → base runtime; end‑users only pick apps in a dashboard and sign in with SSO. We support two runtimes:

- **Imperative runtime:** Docker Compose stacks  
- **Declarative runtime:** NixOS modules/Flakes

A **nested `profiles/` Git repository** (submodule) stores per‑tenant selections and environment.

---

## Repository Layout

```
/compose/
  apps/<app>/fragment.yml         # per-app Compose fragment (services, labels, volumes)
  stacks/                         # base: traefik, idp, tailscale, dashboard
  tools/render.py                 # merges enabled app fragments → stack
/nix/
  flake.nix                       # top-level flake
  modules/<app>.nix               # per-app NixOS module (options + defaults)
  hosts/<host>/configuration.nix  # host roles (flake outputs)
/profiles/                        # NESTED GIT REPO (submodule): tenant config & env
  tenants/<id>/
    selection.yml                 # enabled apps + vars (hostnames, storage, SSO hints)
    env/                          # non-secret env files
    secrets/                      # SOPS-encrypted secrets (optional)
/website/                         # Flask UI for new/load tenant & GitOps (see section below)
.junie/guidelines.md
```

Initialize the submodule:
```
git submodule add <ssh://your-remote/profiles.git> profiles
git submodule update --init --recursive
```

---

## Build / Configuration

### Compose Runtime
- **Fragments** under `/compose/apps/<app>/fragment.yml`. Use Traefik Docker provider labels:
  - `traefik.http.routers.<svc>.rule=Host(\`{{host}}\`)`
  - `traefik.http.routers.<svc>.entrypoints=websecure`
  - `traefik.http.routers.<svc>.tls=true`
- **Selection** lives in `/profiles/tenants/<id>/selection.yml` (schema below).
- **Render → Deploy:**
  ```
  python compose/tools/render.py --tenant profiles/tenants/alice/selection.yml --out out/alice.yml
  docker compose -f out/alice.yml config
  docker compose -f out/alice.yml up -d
  ```
- **Notes:** pin image tags; unique router names; shared media under `/srv/{tenant}/media/...` bind-mounts.

### NixOS Runtime
- **Flakes:** `flake.lock` pins inputs. Each app: `services.<app>.enable = true;` + typed options in `nix/modules/<app>.nix`.
- **Build:**
  ```
  nix flake check
  sudo nixos-rebuild switch --flake .#<host>
  ```
- Ingress and SSO via Nix (Traefik, Keycloak/authentik, Tailscale).

### Identity, Ingress, Private Access
- **IdP:** Keycloak (OIDC). For LDAP‑only apps, deploy authentik **LDAP Outpost**.
- **Ingress:** Traefik via Docker labels; use **ForwardAuth** for apps lacking native OIDC.
- **Private access:** Tailscale MagicDNS; optional `tailscale cert` for internal TLS.

---

## Testing

### What to test
1. **Selection logic:** only chosen apps appear; hostnames flow into Traefik labels.
2. **Compose validity:** `docker compose -f out/<tenant>.yml config` passes.
3. **Nix eval:** `nix flake check` passes; enabling an app yields expected services/units.

### Minimal structural test (example executed)
```python
# sanitize_branch(" Alice+Example ") -> "tenant/alice-example"
# render_selection("friend.local","compose",{...}) returns only enabled apps and fills default hosts.
```

### Adding tests
- **Compose**: `unittest` under `compose/tools/tests/` renders from a real `selection.yml` and asserts services/labels/volumes.
- **Nix**: add `flake checks` to evaluate module options and assert expected units when enabled.

---

## Additional Development Notes
- **Style (Compose):** key order `image, env_file, environment, volumes, labels, depends_on`.
- **Versioning:** pin image tags; canary a tenant before broad rollout.
- **Backups:** restic/Borg with tags per tenant; pre‑update snapshot hook; document restore.
- **SSO:** Prefer OIDC; use authentik LDAP Outpost only when app requires LDAP.
- **Shared storage:** writers (Nextcloud/Immich) own content; scanners (Jellyfin/Plex) mount read‑only.
- **Profiles repo is source of truth:** modify via Git only.

---

## Website (Flask) — tenant UI & GitOps

**Purpose:** Modular web UI in `website/` to **create/load** tenant profiles, choose **Docker Compose** or **NixOS** deployment, toggle services, capture per‑service config, and **generate a profiles branch**. If the user provides Keycloak/authentik details, configure clients where feasible or output exact instructions.

### Starter‑pack (Yes/No in UI)
syncthing, gitlab, immich, pi-hole, qbittorrent, plex, stirling-pdf, vaultwarden, nextcloud, sonarr, habitica, seafile, firefly-iii, openvpn, freshrss, navidrome, radarr, homepage, youtubedl-material, fittrackee, vikunja.

> Native OIDC (Immich, FreshRSS, Seafile) → prompt realm/client details.  
> No native OIDC (Sonarr/Radarr/qBittorrent/Navidrome UI) → protect via **Traefik ForwardAuth** with authentik Proxy Provider.

### Folder layout
```
/website/
  app.py                      # Flask app factory
  requirements.txt            # flask, pydantic, gitpython, pyyaml, python-dotenv
  website/
    __init__.py
    views/{wizard.py,services.py}
    services/                 # one module per app (schema + defaults)
    gitops.py                 # new branch, commit, optional push
    forms.py                  # Pydantic→WTForms/Jinja helpers
    templates/                # Jinja2
    static/
```

### Flows
1) **Landing:** Load existing profile or create new.  
2) **Deployment:** choose `compose` or `nixos`.  
3) **Services:** toggles + per‑service forms from Pydantic models.  
4) **Identity:** capture Keycloak/authentik base URL, realm, client; compute redirect URIs per app.  
5) **Generate:** create `tenant/<slug>`, write:
   - `tenants/<id>/selection.yml`
   - `env/*.env` (non‑secrets), `secrets/*` (SOPS‑encrypted)
6) **Modify:** checkout branch, parse YAML, prefill, commit changes.

### Contracts
`selection.yml`:
```
tenant_domain: friend.local
deployment: compose
services:
  nextcloud:
    host: cloud.friend.local
    options: { db_engine: mariadb }
  plex:
    host: plex.friend.local
    options: {}
```

**Git operations**
- Use GitPython when available; fallback to shell `git`.
- Branch name: `tenant/<slug>` (normalized `[a-z0-9/_-]`).
- No force‑push; prefer PRs.

**Security**
- Do not commit raw secrets; use SOPS (age/GPG).
- When proxied, set proper forwarded headers for OIDC (FreshRSS requires it).

---

## Junie Agent Prompts

### A) Core repo prompt
- Work with `/compose` and `/nix`; do **not** edit `/profiles` directly.
- Compose: add `/compose/apps/<app>/fragment.yml` with Traefik labels and pinned images.
- NixOS: add `/nix/modules/<app>.nix` with `services.<app>.enable` + options; expose via `flake.nix`.
- Always validate via `docker compose ... config` or `nix flake check`.
- Enforce shared storage & SSO patterns; prefer OIDC; use authentik LDAP Outpost only when needed.

### B) Website Builder prompt
You are the engineering agent for the **tenant website** in `website/`.

**Constraints**
- Only write inside `website/` (+ unit tests if any).
- Never mutate `/profiles` outside `gitops.py``.
- The service catalog must be pluggable.

**Tasks**
1. Scaffold the Flask project exactly as in the folder layout (factory + blueprints). Add `requirements.txt` with pinned versions.
2. Implement `website/services/REGISTRY` mapping service ids to Pydantic schemas (required/optional fields, default hostname pattern, `supports_oidc` flag).
3. Build the wizard:
   - Step 1: Load tenant (list `tenant/*` branches) or New tenant (id + domain).
   - Step 2: Deployment: `compose` or `nixos`.
   - Step 3: Services: toggles + auto‑generated forms.
   - Step 4: SSO: capture Keycloak/authentik details; compute redirect URIs per app and show instructions.
4. `gitops.create_profile_branch(tenant_id, selection_dict)` creates `tenant/<slug>`, writes `selection.yml`, `env/*.env`, `secrets/*` (SOPS), commits; optional `push_branch()`.
5. Load/Modify: checkout branch, parse YAML, prefill, save changes with a new commit.
6. For non‑OIDC apps, generate Traefik **ForwardAuth** labels (authentik Proxy Provider); document API/service‑account bypass if needed.
7. Provide a **render plan** preview JSON endpoint; optional CLI hooks to run Compose/Nix validation.
8. Document dev workflow in `website/README.md`.

**Acceptance**
- From the UI I can create a tenant, select deployment, enable some services, enter hosts/options, add IdP details, click *Generate*, and the profiles repo contains a new branch with `selection.yml`. I can load an existing tenant, edit, and save.

---

## Canonical References (for developers)
- Flask: palletsprojects.com (API, Quickstart)
- GitPython docs / PyPI
- Keycloak OIDC guides
- authentik Outposts/LDAP, Traefik ForwardAuth
- Immich OAuth/OIDC; Pi‑hole; qBittorrent (LinuxServer); Plex; Stirling‑PDF; Vaultwarden; Nextcloud; Sonarr/Radarr; FreshRSS OIDC; Navidrome Reverse Proxy Auth; Vikunja; FitTrackee
