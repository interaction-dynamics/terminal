---
feature: true
# TODO: owner
creation_date: 2026-03-06
---

# Blog

Lets a visitor browse the blog posts and read one.

## How it works

- `/blog` (`page.tsx`) lists the posts as cards; `/blog/[postSlug]` renders one post and shows the not-found page for an unknown slug.
- Posts come from the content management adapter (`@ship-it/adapters/content-management`: `fetchPosts`, `fetchOnePost`, `RichText`).
