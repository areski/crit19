defmodule Crit.Usables do
  alias Crit.Sql
  alias Crit.Usables.{Animal, ServiceGap, AnimalServiceGap, Species}
  alias Ecto.Multi
  alias Crit.Ecto.MegaInsert
  alias Crit.Institutions

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

    # When I try to include the final query into the Multi, I get a
    # weird error that I think is some sort of interaction with the
    # `Sql` prefix-handling. That is,
    #        Sql.all(query, "critter4us")
    # fails, but the equivalent
    #        Crit.Repo.all(query, prefix: "demo")
    # works fine.

    query =
      tx_result.animal_ids
      |> Animal.Query.from_ids
      |> Animal.Query.preload_common
    animals = Sql.all(query, institution)

    {:ok, animals}
  end

  def animal_creation_changeset(%Animal{} = animal) do
    Animal.changeset(animal, %{})
  end

  def available_species(institution) do
    Species.Query.ordered()
    |> Sql.all(institution)
    |> Enum.map(fn %Species{name: name, id: id} -> {name, id} end)
  end

end
