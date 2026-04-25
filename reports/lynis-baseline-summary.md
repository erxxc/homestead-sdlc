# Lynis Baseline Report Summary

## Date
Pre-weekend baseline — Block 2

## Hardening Index
65 / 100

## Finding Categories
- Authentication hardening opportunities identified
- Kernel hardening parameters not fully configured
- Audit daemon not installed
- File permission improvements available
- Boot security recommendations noted

## Notes
- Full report retained locally — not committed to version control
- Target hardening index: 75+ after Block 9 remediation
- Full report contains system-specific details unsuitable for public repo

## Next Steps
Apply CIS remediations in Block 9 — Sunday afternoon

## Process Note
Full Lynis report was initially staged for commit. Pre-commit review identified
sensitive system details unsuitable for public repository. PR was closed without
merging. Sanitised summary committed instead. Demonstrates branch protection and
PR review controls functioning as intended.
