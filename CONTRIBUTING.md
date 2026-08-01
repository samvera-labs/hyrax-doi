# Contributing to hyrax-doi

Technical guide to developing and testing this gem. For community guidelines — code of
conduct, commit conventions, and the pull request process — see
[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md).

## How the test harness works

This gem has no test application of its own. It runs against Hyrax's test apps, which come
from a git submodule at `vendor/engines/hyrax`. Docker Compose mounts three directories into
the container:

| Host | Container |
|---|---|
| `vendor/engines/hyrax/.koppie` | `/app/samvera/hyrax-webapp` (the Rails app) |
| `vendor/engines/hyrax` | `/app/samvera/hyrax-engine` (Hyrax itself) |
| `.` (this repo) | `/app/samvera/hyrax-doi` (the gem) |

**Specs run from `/app/samvera/hyrax-doi`**, not from the webapp directory.

### The three test apps

As of 1.0.0 this gem is Valkyrie-only, and every configuration must pass. They differ in
metadata backend and schema mode:

| App | Valkyrie metadata | `HYRAX_FLEXIBLE` | Fedora |
|---|---|---|---|
| **koppie** | Postgres | `false` | no |
| **allinson** | Postgres | `true` | no |
| **sirenia** | Fedora | `false` | yes |

**Both flex modes are required.** This gem is platform code: `HYRAX_FLEXIBLE=false` uses the
simple YAML schema loader, `true` uses the m3 profile-driven loader, and they resolve
attributes, indexing, and show-page rendering differently. A change that works in one can
silently break the other.

**Sirenia matters** because it is the only configuration where Valkyrie resources live in
Fedora while the gem's ActiveRecord tables live in Postgres.

Allinson mounts the **same `.koppie` app directory** as koppie — it is koppie with flex
enabled, not a separate app. It has its own `Gemfile.allinson` purely so it gets its own
lockfile. Sirenia reuses `Gemfile.koppie` (it differs only in runtime configuration), which
is why there is no `Gemfile.sirenia`.

## Setup

Initialize the Hyrax submodule after cloning:

```
git submodule init
git submodule update
```

> **Port conflicts.** These stacks bind the same host ports as a Hyrax checkout's own
> koppie/allinson/sirenia stacks. If you have those running, stop them first
> (`docker compose -f docker-compose-koppie.yml stop` in your Hyrax checkout). The gem's
> three stacks use staggered ports and do not conflict with each other.

## Running specs

Pick a stack, bring it up, and run rspec from the gem directory:

```
docker compose -f docker-compose-koppie.yml up -d
docker compose -f docker-compose-koppie.yml exec -w /app/samvera/hyrax-doi web bash
bundle install
bundle exec rspec
```

Non-interactively, from the host:

```
docker compose -f docker-compose-koppie.yml exec -T -w /app/samvera/hyrax-doi web \
  sh -c "bundle exec rspec spec/services/hyrax/doi/datacite_client_spec.rb"
```

Swap `koppie` for `allinson` or `sirenia` to run the other configurations. **Run all three
before opening a pull request** — CI does.

Each stack needs its own `bundle install` the first time, since allinson uses a different
Gemfile and therefore a different lockfile.

On an Apple Silicon machine, bundler may report that `aarch64-linux` is missing from the
lockfile's platforms. Add it once per lockfile:

```
bundle lock --add-platform aarch64-linux
```

Tear down when finished:

```
docker compose -f docker-compose-koppie.yml down
```

### The `:active_fedora` tag

Specs tagged `:active_fedora` are excluded automatically when Wings is disabled, which is the
case in all three apps. These are ActiveFedora-era specs still awaiting rewrite for Valkyrie;
each will be rewritten or deleted as its part of the port lands. **Do not add new specs with
this tag** — new work should be Valkyrie-native.

## Linting

```
docker compose -f docker-compose-koppie.yml exec -T -w /app/samvera/hyrax-doi web \
  sh -c "bundle exec rubocop"
```

Rubocop must pass before a pull request is merged.

It can also run on the host, which is faster for a quick check. `.ruby-version` pins Ruby 3.3
to match the container and CI; without it a version manager may select an older Ruby that
cannot load the gem's rubocop. The container remains authoritative, since it uses the bundled
rubocop version rather than whatever is installed on the host.

Note the two Ruby versions answer different questions: `.ruby-version` (3.3) is what this
project is developed and tested on, while the gemspec's `required_ruby_version` (>= 3.2) is
the minimum an adopting application needs, matching Hyrax's own floor.

## Rake tasks and generators

Hyrax's rake tasks are available under the `app` namespace (e.g. `rake app:db:migrate`).
Rails generators run normally from the gem root (e.g. `rails g job CheckDOIResolution`).

You shouldn't need to run anything from inside `vendor/engines/hyrax` unless explicitly told
to.

## Hyrax version

The submodule currently tracks Hyrax `main` rather than a release tag. The released
`hyrax-v5.3.0` cannot boot: its `Hyrax::Forms::ResourceForm` includes `CompoundFieldBehavior`,
but the tag does not contain the file defining that constant, so loading the form raises
`NameError`. Hyrax 5.3.0 is otherwise the minimum supported version, because it is the first
release containing the flexible metadata stack. Pin to a release tag once a fixed one ships.
