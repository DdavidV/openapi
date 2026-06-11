defmodule Openapi.Loader.Json do

  def read_file(path) do
    path
    |> File.read!()
    |> JSON.decode!()
  end

end
