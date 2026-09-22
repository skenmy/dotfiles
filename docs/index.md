# skenmy/dotfiles — audit

A standing review of everything the [chezmoi](https://chezmoi.io) source repo at
[skenmy/dotfiles](https://github.com/skenmy/dotfiles) does to a machine: which packages it installs,
which settings it changes, how that differs per profile, where the gaps are, and how to change any of it.

## How to read this site

| You want to know… | Go to |
|---|---|
| What a given kind of machine ends up with | [Profiles](profiles.md) |
| Every package, per OS | [Packages](packages/index.md) |
| Every setting, grouped by tool | Settings section in the sidebar |
| What is broken, risky or inconsistent | [Gap register](gaps.md) |
| How to add, remove or override something | [How to change things](howto.md) |
| Where a source file lands on disk | [File inventory](generated/files.md) |

## Two kinds of page

**Generated pages** (marked with a blue *Generated page* box) are rebuilt from the repository sources
every time `main` changes, by `scripts/docsgen`. They are always current, including after the nightly
`dotfiles-brew-sync` commit. If a number on one of them looks wrong, the source file it names is wrong.

**Hand-written pages** (this one, Profiles, Settings, Gap register, How to) are reviewed judgement.
They carry a *reviewed against commit* line and drift only when someone changes the repo without
updating them. The [how-to page](howto.md#keep-this-site-accurate) says how to keep them honest.

## The profile model in one paragraph

Every machine answers five prompts on first `chezmoi init`: `name`, `email`, `signingKey`
(an on/off flag for SSH commit signing despite its name), `headless` and `work`. Combined with the
detected OS (`darwin`, `linux`, `windows`) those drive `.chezmoiignore` and the `{{ if }}` guards inside
templates and scripts. There are effectively five OS profiles crossed with the `work` flag. The
[Profiles](profiles.md) page has the full matrix.

## Headline numbers

The [Summary](generated/summary.md) page carries the live counts. At the time of this review the
repo held 64 source files, 81 Brewfile entries (6 of them duplicates), 42 macOS defaults, and
57 shell tips.

## Reviewed against

Hand-written pages were last reviewed against commit `ada9e1c` on 2026-09-22.
