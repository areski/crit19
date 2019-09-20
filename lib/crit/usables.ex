defmodule Crit.Usables do
  alias Crit.Sql
  alias Crit.Usables.{Animal, ServiceGap, AnimalServiceGap}
  alias Ecto.Multi
  alias Crit.Sql
  alias Crit.Ecto.MegaInsert
  alias Crit.Institutions

  
  # @moduledoc """
  # The Usables context.
  # """

  # import Ecto.Query, warn: false
  # alias Crit.Repo

  # alias Crit.Usables.Animal

  # @doc """
  # Returns the list of animals.

  # ## Examples

  #     iex> list_animals()
  #     [%Animal{}, ...]

  # """
  # def list_animals do
  #   Repo.all(Animal)
  # end


  def get_complete_animal!(id, institution) do
    query = 
      Animal.Query.from(id: id) |> Animal.Query.preload_common()
    
    case Sql.one(query, institution) do
      nil ->
        raise KeyError, "No animal id #{id}"
      animal ->
        animal
    end
  end

  def get_complete_animal_by_name(name, institution) do
    Animal.Query.from(name: name)
    |> Animal.Query.preload_common()
    |> Sql.one(institution)
  end

  def create_animal(attrs, institution) do
    adjusted_attrs = Map.put(attrs, "timezone", Institutions.timezone(institution))
    
    {:ok, animal_changesets} = Animal.creational_changesets(adjusted_attrs)
    service_gap_changesets = ServiceGap.initial_changesets(adjusted_attrs)

    animal_opts = [schema: Animal, structs: :animals, ids: :animal_ids]
    service_gap_opts = [schema: ServiceGap, structs: :service_gaps, ids: :service_gap_ids]


    animal_multi =
      MegaInsert.make_insertions(animal_changesets, institution, animal_opts)
      |> MegaInsert.append_collecting(animal_opts)
    service_gap_multi =
      MegaInsert.make_insertions(service_gap_changesets, institution, service_gap_opts)
      |> MegaInsert.append_collecting(service_gap_opts)

    connector_function = fn tx_result ->
      MegaInsert.connection_records(tx_result, AnimalServiceGap, :animal_ids, :service_gap_ids)
      |> MegaInsert.make_insertions(institution, schema: AnimalServiceGap)
    end

    {:ok, tx_result} =
      Multi.new
      |> Multi.append(animal_multi)
      |> Multi.append(service_gap_multi)
      |> Multi.merge(connector_function)
      |> Sql.transaction(institution)

    {:ok, tx_result.animals}
  end

  # @doc """
  # Updates a animal.

  # ## Examples

  #     iex> update_animal(animal, %{field: new_value})
  #     {:ok, %Animal{}}

  #     iex> update_animal(animal, %{field: bad_value})
  #     {:error, %Ecto.Changeset{}}

  # """
  # def update_animal(%Animal{} = animal, attrs) do
  #   animal
  #   |> Animal.changeset(attrs)
  #   |> Repo.update()
  # end

  # @doc """
  # Deletes a Animal.

  # ## Examples

  #     iex> delete_animal(animal)
  #     {:ok, %Animal{}}

  #     iex> delete_animal(animal)
  #     {:error, %Ecto.Changeset{}}

  # """
  # def delete_animal(%Animal{} = animal) do
  #   Repo.delete(animal)
  # end

  def change_animal(%Animal{} = animal) do
    Animal.changeset(animal, %{})
  end
end
