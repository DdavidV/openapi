defmodule Openapi.DocsPlug do
  @behaviour Plug

  import Plug.Conn

  @impl true
  def init({action, server}) when is_atom(action), do: {action, server}

  @impl true
  def call(conn, {:index, _server}) do
    base_path = extract_base_path(conn.request_path)

    html =
      :openapi
      |> Application.app_dir("priv/swagger_ui/index.html")
      |> File.read!()
      |> String.replace("__BASE_PATH__", base_path)
      |> String.replace("__OPENAPI_URL__", "#{base_path}/openapi.json")

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  def call(conn, {:spec, server}) do
    definition = Openapi.get_definition(server)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, JSON.encode!(definition))
  end

  def call(conn, {:asset, _server}) do
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
          base_path = extract_base_path(conn.request_path)
          definition_url = "#{base_path}/openapi.json"
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

  defp extract_base_path(request_path) do
    case String.split(request_path, "/", trim: true) do
      [] -> ""
      [base | _] -> "/#{base}"
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
