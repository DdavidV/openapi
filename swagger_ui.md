# Swagger UI Static Assets

priv/swagger_ui directory contains a prebuilt distribution of Swagger UI used by the Openapi library
to render interactive API documentation.

## Source

These files originate from:

https://github.com/swagger-api/swagger-ui

## Version

Swagger UI version: **5.32.0**

## Modifications

Modified files:
- index.html
- swagger-initializer.js

This bundle includes small modifications to make Swagger UI embeddable inside Phoenix applications
and reusable under arbitrary routes.

All static asset paths were modified to use a runtime-replaceable base path. This allows the `Openapi`
library to inject the correct OpenAPI JSON endpoint at runtime depending on the mounted route.

At runtime, the `Openapi` library replaces:
- __BASE_PATH__ → the mounted docs route (e.g. /api-docs)
- __OPENAPI_URL__ → the generated OpenAPI JSON endpoint

## License

Swagger UI is licensed under the Apache License 2.0.

A copy of the license is included below.

---

## Apache License 2.0 Notice

Copyright 2017–present SmartBear Software

Licensed under the Apache License, Version 2.0 (the "License");
you may not use these files except in compliance with the License.
You may obtain a copy of the License at:

https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

---
