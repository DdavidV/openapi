defmodule Openapi.Phoenix do

  defmacro openapi(path, options \\ []) do
    quote bind_quoted: [path: path, options: options] do
      _definition = Openapi.read_file!(path)
      :ok
    end
  end

end
