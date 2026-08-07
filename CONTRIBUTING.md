# Contributing

## Workflow

- Fork the repository and create a feature branch.
- Edit the source files directly, not the release ZIPs.
- Keep changes non-invasive where practical.
- Prefer public Gen1Recomp Mod API hooks and events instead of core file replacement.
- Test gameplay changes before submitting a pull request.
- For releases, update `manifest.json` version and `CHANGELOG.md` together when appropriate.

## Notes

- `main.lua` is the primary mod entry point.
- Keep release packaging source-first and editable in GitHub.
- Do not commit generated release ZIP files into the source tree.
