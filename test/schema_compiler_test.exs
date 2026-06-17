defmodule Openapi.SchemaCompilerTest do
  use ExUnit.Case

  setup_all do
    definition = Openapi.read_file!("test/resources/validation.yaml")
    routes = Openapi.Definition.phoenix_routes(definition)
    schemas = Map.new(routes, &{&1.operation_id, &1.schemas})
    {:ok, definition: definition, schemas: schemas}
  end

  test "compiles body schema for createPet", %{schemas: schemas} do
    create_pet = schemas[:create_pet]
    assert %ExJsonSchema.Schema.Root{} = create_pet.body
    assert create_pet.parameters == []
  end

  test "resolves $ref in body schema", %{schemas: schemas} do
    body = schemas[:create_pet].body
    assert :ok == ExJsonSchema.Validator.validate(body, %{"name" => "Max"})
    assert {:error, _} = ExJsonSchema.Validator.validate(body, %{})
  end

  test "compiles query parameters for listPets", %{schemas: schemas} do
    list_pets = schemas[:list_pets]
    assert is_nil(list_pets.body)

    limit = Enum.find(list_pets.parameters, &(&1.name == "limit"))
    assert limit.in == "query"
    assert limit.required == false
    assert %ExJsonSchema.Schema.Root{} = limit.schema

    status = Enum.find(list_pets.parameters, &(&1.name == "status"))
    assert status.in == "query"
    assert status.required == true
    assert %ExJsonSchema.Schema.Root{} = status.schema
  end

  test "parameter without a schema compiles to a nil schema", %{schemas: schemas} do
    note = Enum.find(schemas[:list_pets].parameters, &(&1.name == "note"))
    assert note.in == "query"
    assert is_nil(note.schema)
  end

  test "compiles path parameter for getPet", %{schemas: schemas} do
    get_pet = schemas[:get_pet]
    assert is_nil(get_pet.body)

    id = Enum.find(get_pet.parameters, &(&1.name == "id"))
    assert id.in == "path"
    assert id.required == true
    assert %ExJsonSchema.Schema.Root{} = id.schema
  end

  test "compile_operation handles operation with no body and no parameters" do
    operation = %{"responses" => %{"200" => %{"description" => "ok"}}}
    result = Openapi.SchemaCompiler.compile_operation(operation, %{})

    assert is_nil(result.body)
    assert result.parameters == []
  end
end
