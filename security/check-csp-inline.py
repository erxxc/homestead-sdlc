#!/usr/bin/env python3
"""Fail when a page contains inline content its own CSP forbids.

Written after a real outage of exactly this shape: the live status indicator sat
on "Checking..." indefinitely because the script that resolves it was an inline
<script>, and the site's CSP is script-src 'self' with no 'unsafe-inline'. The
browser blocked it and said so in the console — but the page still returned 200,
still rendered, and still looked like it was merely loading. Nothing in CI, in
the deploy, or in any log had an opinion about it.

That is what makes this class worth a check: the failure is silent everywhere
except a console nobody has open. A page that is broken this way is
indistinguishable from a page that is slow.

The check reads the policy actually being shipped rather than hardcoding a rule,
so it stays correct as the CSP changes. It compares, per page:

    <script> with no src   against  script-src
    <style> ... </style>   against  style-src
    style="..." attribute  against  style-src
    on*="..." handler      against  script-src
    javascript: URL        against  script-src

A directive missing from the CSP falls back to default-src, as the spec requires.
Only 'unsafe-inline' is treated as a blanket allow. A hash or nonce permits one
specific piece of content and cannot be verified from here, so it downgrades the
finding to a warning rather than silently passing everything.

Usage:
    python3 security/check-csp-inline.py site/public
    python3 security/check-csp-inline.py site/public --list   # show the policy
"""

import fnmatch
import pathlib
import re
import sys

# Directives whose absence falls back to default-src.
FALLBACK = "default-src"

INLINE_CHECKS = (
    # (label, directive, regex) — regex must expose the offending text in group 0
    (
        "inline <script>",
        "script-src",
        re.compile(r"<script(?![^>]*\bsrc\s*=)[^>]*>", re.I),
    ),
    ("inline <style>", "style-src", re.compile(r"<style[^>]*>", re.I)),
    ("style= attribute", "style-src", re.compile(r"\sstyle\s*=\s*[\"']", re.I)),
    ("inline event handler", "script-src", re.compile(r"\son[a-z]+\s*=\s*[\"']", re.I)),
    ("javascript: URL", "script-src", re.compile(r"[\"']javascript:", re.I)),
)


def parse_headers(path):
    """Cloudflare Pages _headers -> [(url_pattern, {header_name_lower: value})].

    Format is a path pattern in column 0 followed by indented "Name: value"
    lines. Continuation is by indentation, not by any explicit terminator.
    """
    rules, pattern, headers = [], None, {}
    for raw in path.read_text().splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if not raw[0].isspace():
            if pattern is not None:
                rules.append((pattern, headers))
            pattern, headers = raw.strip(), {}
        elif ":" in raw:
            name, _, value = raw.strip().partition(":")
            headers[name.strip().lower()] = value.strip()
    if pattern is not None:
        rules.append((pattern, headers))
    return rules


def parse_csp(csp):
    """'script-src 'self'; style-src 'self' 'unsafe-inline'' -> {name: [tokens]}"""
    out = {}
    for chunk in csp.split(";"):
        parts = chunk.split()
        if parts:
            out[parts[0].lower()] = parts[1:]
    return out


def sources_for(directives, name):
    """The effective source list for a directive, honouring default-src fallback."""
    if name in directives:
        return directives[name], name
    if FALLBACK in directives:
        return directives[FALLBACK], FALLBACK
    return None, None


def url_path_for(html_path, root):
    rel = html_path.relative_to(root).as_posix()
    return "/" + rel


def csp_for(url_path, rules):
    """Last matching rule wins, which is how Pages layers them."""
    found = None
    for pattern, headers in rules:
        # a bare "/*" should match every path, including nested ones
        glob = pattern if pattern != "/*" else "/**"
        if fnmatch.fnmatch(url_path, glob) or fnmatch.fnmatch(url_path, pattern):
            if "content-security-policy" in headers:
                found = headers["content-security-policy"]
    return found


def line_of(text, index):
    return text.count("\n", 0, index) + 1


def check_file(html_path, root, rules):
    """-> (errors, warnings) as lists of printable strings."""
    url_path = url_path_for(html_path, root)
    csp = csp_for(url_path, rules)
    if not csp:
        return [], []

    directives = parse_csp(csp)
    errors, warnings = [], []
    text = html_path.read_text()

    for label, directive, pattern in INLINE_CHECKS:
        sources, used = sources_for(directives, directive)
        if sources is None:
            continue  # nothing constrains it
        if "'unsafe-inline'" in sources:
            continue  # explicitly permitted
        hashed = any(
            s.startswith(("'sha256-", "'sha384-", "'sha512-", "'nonce-"))
            for s in sources
        )

        for m in pattern.finditer(text):
            note = (
                f"{html_path.relative_to(root.parent)}:{line_of(text, m.start())}  "
                f"{label} but {used} is [{' '.join(sources)}]"
            )
            (warnings if hashed else errors).append(note)

    return errors, warnings


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = pathlib.Path(args[0] if args else "site/public").resolve()
    if not root.is_dir():
        print(f"not a directory: {root}", file=sys.stderr)
        return 2

    header_files = sorted(root.rglob("_headers"))
    if not header_files:
        print(f"no _headers under {root} — nothing to enforce")
        return 0

    rules = []
    for hf in header_files:
        rules.extend(parse_headers(hf))

    if "--list" in sys.argv:
        for pattern, headers in rules:
            csp = headers.get("content-security-policy")
            if csp:
                print(f"{pattern}")
                for name, sources in parse_csp(csp).items():
                    print(f"    {name}: {' '.join(sources) or '(empty)'}")
        return 0

    errors, warnings, checked = [], [], 0
    for html in sorted(root.rglob("*.html")):
        e, w = check_file(html, root, rules)
        errors += e
        warnings += w
        checked += 1

    for w in warnings:
        print(f"warning: {w}")
        print("         a hash or nonce is present; verify this one by hand")
    for e in errors:
        print(f"ERROR: {e}")

    if errors:
        print(
            f"\n{len(errors)} inline block(s) the CSP will refuse to run. "
            "This fails silently in a browser — the page still returns 200.\n"
            "Move the code to an external same-origin file rather than adding "
            "'unsafe-inline', which would relax the policy for every page."
        )
        return 1

    print(
        f"checked {checked} page(s) against {len(rules)} header rule(s): no CSP-blocked inline content"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
