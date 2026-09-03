# Using Nexus Repository for Dependencies

This project is wired so that npm packages, Android/Gradle dependencies, and
Docker base images are all pulled through a self-hosted **Nexus Repository
Manager** instead of talking to public registries directly. This doc covers
the Nexus-side setup and exactly which files in this repo point at it.

## Why this shape

Nexus's value is as a **caching proxy + private hosting** layer:
- A **proxy** repository mirrors a public registry (npmjs.org, Maven
  Central, Docker Hub) - your builds only ever talk to Nexus, and Nexus
  fetches from upstream on a cache miss.
- A **hosted** repository stores packages you publish yourself (this
  project's `@car-tracker/shared-types` internal package, for example).
- A **group** repository combines both under a single URL, so clients only
  ever need to know one address per ecosystem.

Everywhere in this repo, we point at a **group** URL for exactly that reason.

## 1. Set up Nexus repositories (one-time, done in the Nexus UI)

Create these three group repositories (each aggregating a proxy + optional
hosted repo of the same format):

| Group repo | Aggregates | Used for |
|---|---|---|
| `npm-group` | `npm-proxy` (→ `https://registry.npmjs.org`) + `npm-hosted` | All `npm install` calls (root workspace, `mobile/`, each service's isolated Docker build context) |
| `maven-group` | `maven-google-proxy` (→ `https://dl.google.com/dl/android/maven2/`) + `maven-central-proxy` (→ `https://repo1.maven.org/maven2/`) + `gradle-plugin-proxy` (→ `https://plugins.gradle.org/m2/`) | Android Gradle dependency resolution |
| `docker-group` | `docker-proxy` (→ `https://registry-1.docker.io`) | Base images (`node:20-alpine`, etc.) in both Dockerfiles |

Nexus Repository Manager: **Settings → Repositories → Create repository**,
pick the matching recipe (`npm (proxy)`, `maven2 (proxy)`, `docker (proxy)`,
etc.) for each, then a `(group)` recipe combining them.

For the Docker group specifically, Nexus needs a dedicated HTTP connector
port (e.g. `8083`) configured under **Repository → docker-group → HTTP** -
this is why Docker image references look like
`nexus.yourcompany.example.com:8083/node:20-alpine` (host:port, no `/repository/...` path).

## 2. Where each ecosystem is wired up in this repo

### npm

| File | Purpose |
|---|---|
| `.npmrc` (repo root) | Used by `npm install` at the workspace root (`libs/*`, `services/*`) |
| `mobile/.npmrc` | Used by `npm install` in the mobile app |
| `services/auth-service/.npmrc` | Copied into that service's **isolated** Docker build context (its own `.dockerignore`-scoped folder never sees the root `.npmrc`) |
| `services/core-service/.npmrc` | Same, for core-service |

All four point at `registry=https://nexus.yourcompany.example.com/repository/npm-group/`
— **replace that hostname with your real Nexus instance** in all four files
before running `npm install` anywhere in this project. The auth token line
uses `${NEXUS_NPM_TOKEN}` (npm's plain env-var substitution - no bash-style
`${VAR:-default}` fallback syntax is supported in `.npmrc`), so set
`NEXUS_NPM_TOKEN` in your shell/CI environment. Generate a token in Nexus
via your user icon → "NPM Realm Token", or use a service-account token in CI.

**Internal package note:** `@car-tracker/shared-types` is this monorepo's
own internal package. Locally, npm workspaces always resolve it via a
symlink to `libs/shared-types` regardless of what's on Nexus. But each
service's Docker build context is isolated from the rest of the monorepo,
so for `npm install` to succeed *inside a container build*, the package
must actually exist somewhere npm can fetch it — which is exactly what
Nexus's `npm-hosted` repo is for:

```bash
cd libs/shared-types
npm run build
npm run publish:nexus   # runs `npm publish`, routed to npm-hosted via publishConfig.registry in package.json
```

Bump `libs/shared-types/package.json`'s `version` and re-publish whenever
its contents change, and keep both services' `"@car-tracker/shared-types"`
dependency range (`^0.1.0`) in step with whatever's published.

### Android / Gradle

| File | Purpose |
|---|---|
| `mobile/android/build.gradle` | `buildscript.repositories` points at `maven-group` instead of `google()`/`mavenCentral()` directly - covers resolving the Android Gradle Plugin, Kotlin plugin, and React Native Gradle plugin classpaths |
| `mobile/android/nexus-init.gradle` | A Gradle **init script** - see below for why this, not just the file above, is what actually guarantees every dependency goes through Nexus |
| `mobile/android/gradle.properties` | Commented-out `nexusUsername`/`nexusPassword` properties, with a note to set them in `~/.gradle/gradle.properties` (never this committed file) |

**Why the init script matters:** the React Native Gradle plugin
(`com.facebook.react.rootproject`, applied in `build.gradle`) auto-injects
its own `google()`/`mavenCentral()` repositories for the `:app` module
internally - editing this project's `build.gradle` alone can't override
that. A Gradle **init script** runs before any project's `build.gradle` is
evaluated, so declaring the Nexus repository there means it's always
checked *first*; Gradle stops at the first repository that has the
requested artifact, so as long as `maven-group` proxies everything needed
(Google's Maven repo + Maven Central + Gradle Plugin Portal), the RN
plugin's own public repositories are never actually contacted.

To use it:
```bash
# Option A - this machine only, affects every Gradle project you build:
cp mobile/android/nexus-init.gradle ~/.gradle/init.d/nexus-init.gradle

# Option B - this project only, explicit:
cd mobile/android
./gradlew build --init-script nexus-init.gradle
```
Set `NEXUS_MAVEN_GROUP_URL`, `NEXUS_USERNAME`, `NEXUS_PASSWORD` as
environment variables before running Gradle (or as `~/.gradle/gradle.properties`
properties `nexusUsername`/`nexusPassword`, read as a fallback).

### Docker base images

| File | Purpose |
|---|---|
| `services/auth-service/Dockerfile` | `ARG BASE_REGISTRY=docker.io/library`, used in both `FROM ${BASE_REGISTRY}/node:20-alpine` lines |
| `services/core-service/Dockerfile` | Same |
| `scripts/linux/k8s-build-images.sh` / `scripts/windows/k8s-build-images.ps1` | Pass `--build-arg BASE_REGISTRY=$NEXUS_DOCKER_PROXY` and mount the npm token as a BuildKit secret |
| `docker-compose.yml` | Same, via `args: BASE_REGISTRY: ${NEXUS_DOCKER_PROXY:-docker.io/library}` and a `secrets:` block |
| `.gitlab-ci.yml` | Same, via the `NEXUS_DOCKER_PROXY_HOST` CI/CD variable (defaults to `docker.io/library` so the pipeline works before Nexus is set up) |

The npm auth token is never passed as a plain `--build-arg` (those persist
in image history/layers, which is a real leak risk for anything you'd push
to a shared registry). Instead it's injected via a **BuildKit secret
mount** (`RUN --mount=type=secret,id=npm_token,...` in both Dockerfiles),
which is only available to that one `RUN` step and never written to a layer.

To build with Nexus:
```bash
export NEXUS_DOCKER_PROXY="nexus.yourcompany.example.com:8083"
echo -n "your-real-token" > secrets/nexus_npm_token.txt
./scripts/linux/k8s-build-images.sh
```
(`secrets/nexus_npm_token.txt` ships empty in this repo, gitignored once
you edit it, so `docker build`/`docker compose build` work immediately
without Nexus - an empty token just means anonymous npm reads, which is
fine if your `npm-group` repo allows anonymous access for reads.)

## 3. CI/CD (GitLab CE)

Set these as CI/CD variables (Project or Group → Settings → CI/CD →
Variables), masking the token ones:

| Variable | Purpose |
|---|---|
| `NEXUS_DOCKER_PROXY_HOST` | e.g. `nexus.yourcompany.example.com:8083/library` - overrides the `docker.io/library` default in `.gitlab-ci.yml` |
| `NEXUS_NPM_TOKEN` | Passed into the Docker build as a BuildKit secret (`--secret id=npm_token,env=NEXUS_NPM_TOKEN`) and used directly by `npm ci`/`npm install` steps via `.npmrc`'s `${NEXUS_NPM_TOKEN}` substitution |

The pipeline works before you set these (falls back to public registries) -
add them whenever you're ready to switch CI over to Nexus too.

## 4. iOS / CocoaPods - an honest limitation

**Nexus does not have a native CocoaPods repository format.** Unlike npm,
Maven, and Docker, there's no `cocoapods (proxy)` recipe in Nexus OSS or
Nexus Pro. Practical options if you need iOS dependencies proxied too:

- **Do nothing special** - CocoaPods continues pulling directly from the
  public [CocoaPods Specs CDN](https://cdn.cocoapods.org) and GitHub, while
  everything else (npm, Gradle, Docker) goes through Nexus. This is the
  simplest option and what this project ships with by default.
- **Host a private Podspecs repo** - if you need to distribute an internal
  iOS pod, host its podspec in a private Git repo and add it as a Podfile
  `source`, entirely separate from Nexus.
- **Switch to JFrog Artifactory** for the iOS piece specifically, if a
  single-vendor proxy solution across every ecosystem (including
  CocoaPods, which Artifactory does support) is a hard requirement.

## 5. Quick reference - what needs editing before this works for real

1. Replace `nexus.yourcompany.example.com` in `.npmrc`, `mobile/.npmrc`,
   `services/auth-service/.npmrc`, `services/core-service/.npmrc` with your
   real Nexus hostname.
2. Replace the same placeholder in `mobile/android/build.gradle` and
   `mobile/android/nexus-init.gradle` (`NEXUS_MAVEN_GROUP_URL` default).
3. Set `NEXUS_NPM_TOKEN` (env var, wherever you run `npm install`).
4. Set `NEXUS_USERNAME` / `NEXUS_PASSWORD` (env vars, wherever you run Gradle).
5. Set `NEXUS_DOCKER_PROXY` (env var) or `NEXUS_DOCKER_PROXY_HOST` (GitLab
   CI/CD variable) to your Nexus Docker group's `host:port`.
6. Publish `@car-tracker/shared-types` to your Nexus `npm-hosted` repo
   (`cd libs/shared-types && npm run build && npm run publish:nexus`).
