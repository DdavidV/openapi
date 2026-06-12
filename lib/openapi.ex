defmodule Openapi do

  def read_file!(path) do
    path
    |> Path.extname()
    |> normalize_ext()
    |> dispatch!(path)
  end

  defp normalize_ext("." <> ext), do: ext
  defp normalize_ext(ext), do: ext

  defp dispatch!(ext, path) when ext in ["yaml", "yml"], do: Openapi.Loader.Yaml.read_file(path)
  defp dispatch!("json", path), do: Openapi.Loader.Json.read_file(path)
  defp dispatch!(_ext, path) do
    raise ArgumentError, "Unsupported file extention: #{path}"
  end

  def get_definition(server, default \\ %{}) do
    :persistent_term.get({:openapi, :specs, server}, default)
  end

  def save_definition(server, definition) do
    merged_definition =
      server
      |> get_definition()
      |> Openapi.Definition.merge(definition)
    :persistent_term.put({:openapi, :specs, server}, merged_definition)
  end

end
