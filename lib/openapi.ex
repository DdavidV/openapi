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

end
