defmodule Openapi.DocsPlug do
  @moduledoc """
  Plug responsible for serving OpenAPI documentation and Swagger UI assets.

  It is typically mounted through `Openapi.swagger_docs/2` and handles three
  different request types:

  ## 1. Swagger UI entrypoint (`:index`)

  Renders the Swagger UI HTML shell and injects runtime configuration such as:

    - Base path where the docs are mounted
    - URL to the generated OpenAPI JSON (`/openapi.json`)

  This enables the Swagger UI frontend to correctly load API metadata.

  ## 2. OpenAPI specification (`:spec`)

  Returns the compiled OpenAPI definition as JSON. This definition is retrieved
  from the server registered via the `:server` option.

  ## 3. Static Swagger UI assets (`:asset`)

  Serves static files required by Swagger UI, such as:

    - JavaScript bundles
    - CSS stylesheets
    - images and icons

  Files are resolved from the application's `priv/swagger_ui` directory.

  The plug ensures that only files inside this directory are accessible.
  """

  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(options), do: options

  @impl true
  def call(conn, {:index, _server, mount_path}) do
    html =
      :openapi
      |> Application.app_dir("priv/swagger_ui/index.html")
      |> File.read!()
      |> String.replace("__BASE_PATH__", mount_path)
      |> String.replace("__OPENAPI_URL__", "#{mount_path}/openapi.json")

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  def call(conn, {:spec, server, _mount_path}) do
    definition = Openapi.get_definition(server)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, JSON.encode!(definition))
  end

  def call(conn, {:asset, _server, mount_path}) do
    base_dir =
      :openapi
      |> Application.app_dir("priv/swagger_ui")
      |> Path.expand()

    asset =
      conn.path_params["path"]
      |> List.wrap()
      |> Enum.join("/")

    requested_asset = Path.expand(asset, base_dir)

    if not String.starts_with?(requested_asset, base_dir) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(403, JSON.encode!(%{"error" => "forbidden"}))
    else
      case File.read(requested_asset) do
        {:ok, content} ->
          definition_url = "#{mount_path}/openapi.json"

          content =
            if String.ends_with?(asset, "swagger-initializer.js") do
              String.replace(content, "__OPENAPI_URL__", definition_url)
            else
              content
            end

          conn
          |> put_resp_content_type(content_type(asset))
          |> send_resp(200, content)

        {:error, _} ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(404, JSON.encode!(%{"error" => "Not found"}))
      end
    end
  end

  defp content_type(filename) do
    case Path.extname(filename) do
      ".css" -> "text/css"
      ".js" -> "application/javascript"
      ".png" -> "image/png"
    end
  end
end
