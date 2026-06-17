defmodule Openapi.SchemaCompiler do
  @moduledoc """
  Compiles the JSON schemas of a single OpenAPI operation into pre-resolved `ExJsonSchema` schemas
  for use by `Openapi.ValidatorPlug` and `Openapi.ResponseValidatorPlug`.

  This is called at route-generation time (from `Openapi.Definition.phoenix_routes/1`),
  so the resulting schemas are embedded directly into each route's `private.openapi`
  metadata at compile time.

  For an operation, it extracts:

  - The `requestBody` schema for `application/json` content
  - All `parameters` entries with their schemas
  - The `responses` schemas per status code (for `application/json` content)

  All `$ref` pointers (e.g. `#/components/schemas/Pet`) are resolved inline against the
  full definition before being passed to `ExJsonSchema.Schema.resolve/1`, producing
  self-contained, pre-resolved schemas with zero per-request overhead.
  """

  @doc """
  Compiles the request body, parameter, and response schemas of a single OpenAPI `operation`.

  `$ref` pointers are resolved against the full `definition`.
  """
  def compile_operation(operation, definition) do
    %{
      body: body_schema(operation, definition),
      parameters: parameters(operation, definition),
      responses: response_schemas(operation, definition)
    }
  end

  defp body_schema(operation, definition) do
    case get_in(operation, ["requestBody", "content", "application/json", "schema"]) do
      nil -> nil
      schema -> schema |> dereference(definition) |> ExJsonSchema.Schema.resolve()
    end
  end

  defp parameters(operation, definition) do
    operation
    |> Map.get("parameters", [])
    |> Enum.map(fn param ->
      schema =
        case Map.get(param, "schema") do
          nil -> nil
          s -> s |> dereference(definition) |> ExJsonSchema.Schema.resolve()
        end

      %{
        name: param["name"],
        in: param["in"],
        required: param["required"] || false,
        schema: schema
      }
    end)
  end

  defp response_schemas(operation, definition) do
    operation
    |> Map.get("responses", %{})
    |> Enum.reduce(%{}, fn {status_str, response}, acc ->
      case Integer.parse(status_str) do
        {status_int, ""} ->
          schema =
            case get_in(response, ["content", "application/json", "schema"]) do
              nil -> nil
              s -> s |> dereference(definition) |> ExJsonSchema.Schema.resolve()
            end

          Map.put(acc, status_int, schema)

        _ ->
          # Skip wildcard ("4XX") and "default" status codes
          acc
      end
    end)
  end

  # Recursively dereferences local $ref pointers (e.g. "#/components/schemas/Pet")
  # against the full OpenAPI definition, producing an inlined schema.
  # External $ref values (not starting with "#") are left unchanged.
  defp dereference(%{"$ref" => "#" <> pointer}, definition) do
    keys =
      pointer
      |> String.split("/")
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&unescape/1)

    get_in(definition, keys) |> dereference(definition)
  end

  defp dereference(schema, definition) when is_map(schema) do
    Map.new(schema, fn {k, v} -> {k, dereference(v, definition)} end)
  end

  defp dereference(schema, definition) when is_list(schema) do
    Enum.map(schema, &dereference(&1, definition))
  end

  defp dereference(value, _definition), do: value

  # Unescapes a single JSON Pointer segment (RFC 6901).
  # Because "/" separates segments and "~" starts an escape, a key that literally contains those
  # characters is encoded in a $ref as "~1" (/) and "~0" (~).
  # This reverses that so we look up the real key, e.g. "#/paths/~1pets~1{id}" -> key "/pets/{id}".
  defp unescape(segment) do
    segment
    |> String.replace("~1", "/")
    |> String.replace("~0", "~")
  end
end
