## 0.1.1 (2026 June 14)

### Fixes
- swagger_docs macro no longer ignores `server` option
- putting either macro inside a scope would make swagger-ui unuseable, for this reason ˙prefix`
  option is implemented for both macros

### Enhancements
- added documentation
- `mix format`
- `Openapi.read_file!/1` merges parsed definition with default values so that a bare minimum definition
  can also be understood by swagger-ui

## 0.1.0 (2026 June 13)
Initial release.

Features:
- Openapi.Phoenix macros
  - openapi: Serve openapi paths in a phoenix router
  - swagger_docs: Serve swagger-ui on a given path