defmodule Openapi.DefinitionTest do
  use ExUnit.Case

  test "Read alway generates bare minimum" do
    definition = Openapi.read_file!("test/resources/empty.yaml")
    assert match?(%{"openapi" => _, "info" => _, "paths" => _}, definition)
  end

  test "Read yaml definition" do
    definition = Openapi.read_file!("test/resources/petstore_openapi_3.2.0.yaml")
    assert match?(%{"openapi" => "3.2.0"}, definition)
    assert 19 == length(Openapi.Definition.phoenix_routes(definition))
  end

  test "Read yml definition" do
    definition = Openapi.read_file!("test/resources/petstore_openapi_3.2.0.yml")
    assert match?(%{"openapi" => "3.2.0"}, definition)
    assert 19 == length(Openapi.Definition.phoenix_routes(definition))
  end

  test "Read json definition" do
    definition = Openapi.read_file!("test/resources/petstore_openapi_3.0.4.json")
    assert match?(%{"openapi" => "3.0.4"}, definition)
    assert 19 == length(Openapi.Definition.phoenix_routes(definition))
  end

  test "Read definition from {app, relative_path} tuple" do
    priv_dir = :code.priv_dir(:openapi)
    relative_path = "definition_tuple_test.json"
    target = Path.join(priv_dir, relative_path)
    File.cp!("test/resources/petstore_openapi_3.0.4.json", target)
    on_exit(fn -> File.rm(target) end)

    definition = Openapi.read_file!({:openapi, relative_path})
    assert match?(%{"openapi" => "3.0.4"}, definition)
    assert 19 == length(Openapi.Definition.phoenix_routes(definition))
  end

  test "Unsupported definition file" do
    assert_raise Openapi.Error, fn ->
      Openapi.read_file!("test/resources/unsupported.txt")
    end

    assert_raise Openapi.Error, fn ->
      Openapi.read_file!("test/resources/unsupported")
    end
  end

  test "Merge definition with self" do
    definition = Openapi.read_file!("test/resources/petstore_openapi_3.2.0.yml")
    assert definition == Openapi.Definition.merge(definition, definition)
  end

  test "Merge servers" do
    definition1 = %{
      "servers" => [
        %{"url" => "https://api.v1.example.com"}
      ]
    }

    definition2 = %{
      "servers" => [
        %{"url" => "https://api.v2.example.com"},
        %{"url" => "https://api.v1.example.com"}
      ]
    }

    merged = Openapi.Definition.merge(definition1, definition2)

    assert merged["servers"] == [
             %{"url" => "https://api.v1.example.com"},
             %{"url" => "https://api.v2.example.com"}
           ]
  end

  test "Merge tags" do
    definition1 = %{
      "tags" => [
        %{"name" => "users"},
        %{"name" => "auth"}
      ]
    }

    definition2 = %{
      "tags" => [
        %{"name" => "pets"},
        %{"name" => "billing"}
      ]
    }

    merged = Openapi.Definition.merge(definition1, definition2)

    assert merged["tags"] == [
             %{"name" => "users"},
             %{"name" => "auth"},
             %{"name" => "pets"},
             %{"name" => "billing"}
           ]
  end

  test "Merge paths" do
    definition1 = %{
      "paths" => %{
        "/users" => %{
          "get" => %{
            "operationId" => "listUsers"
          }
        }
      }
    }

    definition2 = %{
      "paths" => %{
        "/pets" => %{
          "get" => %{
            "operationId" => "listPets"
          }
        }
      }
    }

    merged = Openapi.Definition.merge(definition1, definition2)

    assert merged["paths"] == %{
             "/users" => %{
               "get" => %{
                 "operationId" => "listUsers"
               }
             },
             "/pets" => %{
               "get" => %{
                 "operationId" => "listPets"
               }
             }
           }
  end

  test "Merge components" do
    definition1 = %{
      "components" => %{
        "schemas" => %{
          "User" => %{
            "type" => "object",
            "properties" => %{
              "id" => %{"type" => "integer"}
            }
          }
        }
      }
    }

    definition2 = %{
      "components" => %{
        "schemas" => %{
          "Pet" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string"}
            }
          }
        }
      }
    }

    merged = Openapi.Definition.merge(definition1, definition2)

    assert merged["components"]["schemas"] == %{
             "User" => %{
               "type" => "object",
               "properties" => %{
                 "id" => %{"type" => "integer"}
               }
             },
             "Pet" => %{
               "type" => "object",
               "properties" => %{
                 "name" => %{"type" => "string"}
               }
             }
           }
  end

  test "Retrieve and save definition" do
    server = :server
    assert %{} = Openapi.get_definition(server)
    definition = Openapi.read_file!("test/resources/petstore_openapi_3.2.0.yml")
    assert :ok == Openapi.save_definition(server, definition)
    assert match?(%{"openapi" => "3.2.0"}, Openapi.get_definition(server))

    # Saving an empty definition will not change the saved definition
    assert :ok == Openapi.save_definition(server, %{})
    assert match?(%{"openapi" => "3.2.0"}, Openapi.get_definition(server))

    # Delete definition from persistent_term to not interfere with other tests
    :persistent_term.erase({:openapi, :specs, server})
  end

  test "prefixes simple paths" do
    definition = %{
      "paths" => %{
        "/users" => %{"get" => %{}},
        "/posts" => %{"get" => %{}}
      }
    }

    result = Openapi.Definition.prefix_routes(definition, "/v1")

    assert result["paths"] == %{
             "/v1/users" => %{"get" => %{}},
             "/v1/posts" => %{"get" => %{}}
           }
  end

  test "prefixes simple paths with nil" do
    definition = %{
      "paths" => %{
        "/users" => %{"get" => %{}},
        "/posts" => %{"get" => %{}}
      }
    }

    result = Openapi.Definition.prefix_routes(definition, nil)

    assert result["paths"] == %{
             "/users" => %{"get" => %{}},
             "/posts" => %{"get" => %{}}
           }
  end
end
