# Product

> **Scope note (read this):** This documents the **upstream Bambuddy WEB app**. It is
> **brand/product reference only** for this team's actual target — the Android app at
> `apps/filament-assignment-android/`. It is **not** an Android spec, and `frontend/` is
> read-only. See `/AGENTS.md`.

## Register

product

## Users

Bambuddy is used by makers, print-farm operators, and self-hosted Bambu Lab printer owners who want local control over one printer or a multi-printer farm. Operators often work near printers, AMS units, spools, shelves, and labels, and may use phones, tablets, kiosks, or desktop browsers depending on the task.

## Product Purpose

Bambuddy is a self-hosted command center for Bambu Lab printers. It replaces cloud-dependent workflows with local printer monitoring, print dispatch, queueing, archive management, slicing, inventory tracking, Spoolman integration, and farm automation. Success means operators can confidently run printers, assign filament, recover history, and make scheduling decisions without switching tools or relying on cloud services.

## Brand Personality

Practical, independent, and operator-focused. The product voice should be direct and specific, with calm confidence rather than hype. Interfaces should feel like reliable workshop software: dense enough for repeated use, clear enough for phone operation, and respectful of the user's local data and hardware.

## Anti-references

Avoid cloud-first SaaS marketing tropes, decorative dashboards that hide the primary action, mobile flows that require desktop setup at the moment of use, and designs that make a print-farm operator read explanatory text while holding a spool or standing beside a machine. Avoid exposing secrets, duplicating source-of-truth data, or creating parallel workflows that conflict with Bambuddy or Spoolman.

## Design Principles

1. Put the operator's next action first.
2. Preserve the existing source of truth for printers, inventory, and Spoolman data.
3. Make high-risk actions explicit, especially replacements, moves, deletes, and printer control.
4. Design for workshop conditions: phones, gloves, labels, intermittent connectivity, and repeated scanning.
5. Prefer clear operational state over decorative polish.

## Accessibility & Inclusion

Target WCAG AA contrast for app text and controls. Preserve keyboard and screen-reader access for forms and confirmation flows. Support reduced-motion preferences. Do not rely on color alone for printer, spool, or conflict state. Mobile controls should be touch-friendly and readable in workshop lighting.
