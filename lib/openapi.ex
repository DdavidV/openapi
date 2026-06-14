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
  Retrieves the OpenAPI definition for a given server from `:persistent_term`.
  """
  def get_definition(server, default \\ %{}) do
    :persistent_term.get({:openapi, :specs, server}, default)
  end

  @doc """
  Stores the OpenAPI definition for a given server in `:persistent_term`.

  The provided definition is merged with any previously registered definition for the same server
  before being stored.
  """
  def save_definition(server, definition) do
    merged_definition =
      server
      |> get_definition()
      |> Openapi.Definition.merge(definition)

    :persistent_term.put({:openapi, :specs, server}, merged_definition)
  end
end
