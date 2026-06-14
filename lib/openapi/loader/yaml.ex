defmodule Openapi.Loader.Yaml do
  def read_file(path) do
    YamlElixir.read_from_file!(path)
  end
end
