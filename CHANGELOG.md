## 0.2.0 (2026 June 16) BREAKING CHANGE!

Users now required to use `use Openapi.Phoenix` instead of `import Openapi.Phoenix` in their routers

### Fixes
- definitions were only available during the initial compilation thus swagger-ui was broken most of
  the times. For this reason `Openapi.Phoenix` was changed to create module parameters for openapi
  files. Furthermore modules are now registered on_load to a list of routers located in `persistent_term`.

### Enhancements
- definitions are not loaded to the `persistent_term` by default it has been switched to load only
  when the resource is needed.

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