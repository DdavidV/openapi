defmodule Openapi.DocsPlug do
  import Plug.Conn

  def init(action), do: action

  def call(conn, :index) do
    html =
      :openapi
      |> Application.app_dir("priv/swagger_ui/index.html")
      |> File.read!()
      |> String.replace("__OPENAPI_URL__", "/api-docs/openapi.json")

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  def call(conn, :spec) do
    json = :persistent_term.get(:openapi)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, JSON.encode!(json))
  end

  def call(conn, :asset) do
    # Get the asset filename from either the wildcard path or the request path
    asset =
      case conn.path_params["path"] do
        path when is_list(path) -> Enum.join(path, "/")
        path when is_binary(path) -> path
        nil -> String.trim_leading(conn.request_path, "/api-docs/")
      end

    file =
      :openapi
      |> Application.app_dir("priv/swagger_ui/#{asset}")

    case File.read(file) do
      {:ok, content} ->
        # Special handling for swagger-initializer.js to inject the OpenAPI URL
        content =
          if String.ends_with?(asset, "swagger-initializer.js") do
            String.replace(content, "__OPENAPI_URL__", "/api-docs/openapi.json")
          else
            content
          end

        conn
        |> put_resp_content_type(content_type(asset))
        |> send_resp(200, content)
      {:error, _} ->
        conn
        |> send_resp(404, "Not found")
    end
  end

  defp content_type(filename) do
    case Path.extname(filename) do
      ".css" -> "text/css"
      ".js" -> "application/javascript"
      ".json" -> "application/json"
      ".html" -> "text/html"
      ".png" -> "image/png"
      ".svg" -> "image/svg+xml"
      ".ico" -> "image/x-icon"
      _other -> "application/octet-stream"
    end
  end
end
