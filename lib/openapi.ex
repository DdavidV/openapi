defmodule Openapi do
  # This can change at any time and only returns a string so just ignore it.
  # coveralls-ignore-start
  @doc """
  Returns the bundled Swagger UI version used by the OpenAPI integration.

  This value corresponds to the static Swagger UI assets shipped with the library
  and is used for serving the documentation frontend.
  """
  def swagger_ui_version, do: "5.32.0"
  # coveralls-ignore-stop

  @doc """
  Reads and parses an OpenAPI definition file.

  Supports multiple file formats (e.g. YAML, JSON) by dispatching to the appropriate parser based on
  the file extension.
  """
  def read_file!(path) do
    path
    |> Path.extname()
    |> normalize_ext()
    |> dispatch!(path)
    |> Openapi.Definition.normalize()
  end

  defp normalize_ext("." <> ext), do: ext
  defp normalize_ext(ext), do: ext

  defp dispatch!(ext, path) when ext in ["yaml", "yml"], do: Openapi.Loader.Yaml.read_file(path)
  defp dispatch!("json", path), do: Openapi.Loader.Json.read_file(path)
  defp dispatch!(_ext, path), do: raise(Openapi.Error, "Unsupported file extention: #{path}")

  @doc """
  Returns the cached OpenAPI definition for the given server.

  If no cached definition exists, it builds it via `find_definition/1` and returns the result.

  `find_definition/1` collects all registered routers, extracts their OpenAPI files, filters by
  server, builds the definitions, merges them, and persists the result via `save_definition/2`.
  """
  def get_definition(server) do
    case :persistent_term.get({:openapi, :specs, server}, %{}) do
      definition when map_size(definition) == 0 ->
        find_definition(server)

      definition ->
        definition
    end
  end

  defp find_definition(server) do
    definition =
      :persistent_term.get({:openapi, :routers}, [])
      |> Enum.flat_map(fn router ->
        router.__openapi_files__()
      end)
      |> Enum.filter(&(&1.server == server))
      |> Enum.reduce(%{}, fn data, acc ->
        definition =
          Openapi.read_file!(data.file)
          |> Openapi.Definition.prefix_routes(data.prefix)

        Openapi.Definition.merge(acc, definition)
      end)

    save_definition(server, definition)
    definition
  end

  @doc """
  Stores the OpenAPI definition in persistent storage for the given server.
  """
  def save_definition(_server, definition) when map_size(definition) == 0, do: :ok

  def save_definition(server, definition) do
    :persistent_term.put({:openapi, :specs, server}, definition)
  end
end
