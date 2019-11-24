defmodule Crit.Usables.HiddenSchemas.ServiceGapTest do
  use Crit.DataCase
  alias Crit.Usables.AnimalApi
  alias Crit.Usables.Schemas.Animal
  alias Crit.Usables.HiddenSchemas.ServiceGap
  alias Crit.Usables.FieldConverters.ToDate
  alias Ecto.Datespan
  alias Crit.Exemplars.Available
  alias Crit.Sql


  describe "changeset for insertion" do
    defp handle(attrs), do: ServiceGap.changeset(%ServiceGap{}, attrs)
    
    test "in- and out-of-service dates are converted..." do
      %{changes: changes} = changeset =
        handle(%{in_service_date: @iso_date,
                 out_of_service_date: @later_iso_date,
                 reason: "reason"})
      assert changeset.valid?
      assert changes.in_service_date == @date
      assert changes.out_of_service_date == @later_date
      assert changes.reason == "reason"
    end

    test "... span is set on success" do
      %{changes: changes} =
        handle(%{in_service_date: @iso_date,
                 out_of_service_date: @later_iso_date,
                 reason: "reason"})
      assert changes.span == Datespan.customary(@date, @later_date)
    end

    test "required fields are checked" do
      changeset = handle(%{})
      errors = errors_on(changeset)

      # Note that animal_id does not have to be present if we're always
      # manipulating service gaps via the animal they belong to.

      assert errors.in_service_date
      assert errors.out_of_service_date
      assert errors.reason
      assert_span_has_not_been_added(changeset)
    end

    test "dates must be in the right order" do
      %{changes: changes} = changeset =
        handle(%{in_service_date: @iso_date,
                 out_of_service_date: @iso_date,
                 reason: "reason"})
      refute changeset.valid?
      assert ToDate.misorder_error_message in errors_on(changeset).out_of_service_date
      assert changes.in_service_date == @date
      assert changes.out_of_service_date == @date
      assert changes.reason == "reason"
      assert_span_has_not_been_added(changeset)
    end
  end

  describe "direct manipulation of changesets: CREATE and READ" do
    setup do
      attrs = attrs(@iso_date, @later_iso_date, "reason")
      insertion_result = insert(attrs)
      retrieved_gap = Sql.get(ServiceGap, insertion_result.id, @institution)
      [attrs: attrs, insertion_result: insertion_result, retrieved_gap: retrieved_gap]
    end
      
    test "insertion", %{insertion_result: result, attrs: attrs} do
      assert result.animal_id == attrs.animal_id
      assert result.span == Datespan.customary(@date, @later_date)
      assert result.reason == attrs.reason
      # We also get the virtual fields.
      # The date fields are converted, which is OK because EEX knows
      # how to convert them to ISO8601 strings in HTML.
      assert result.in_service_date == @date
      assert result.out_of_service_date == @later_date
    end

    test "fetching does not fill in virtual fields...",
      %{retrieved_gap: retrieved, attrs: attrs} do

      # We get the non-virtual fields
      assert retrieved.animal_id == attrs.animal_id
      assert retrieved.span == Datespan.customary(@date, @later_date)
      assert retrieved.reason == attrs.reason

      # but...
      refute retrieved.in_service_date
      refute retrieved.out_of_service_date
    end

    test "... so there's a function for that",
      %{retrieved_gap: retrieved, attrs: attrs} do
      complete = ServiceGap.complete_fields(retrieved)

      assert complete.in_service_date == @date
      assert complete.out_of_service_date == @later_date

      # And other fields are still there
      assert complete.animal_id == attrs.animal_id
      assert complete.span == Datespan.customary(@date, @later_date)
      assert complete.reason == attrs.reason
    end
  end

  describe "date processing on update" do

    @date_bump Date.add(@date, 1)
    @iso_date_bump Date.to_iso8601(@date_bump)

    @later_date_bump Date.add(@later_date, 1)
    @later_iso_date_bump Date.to_iso8601(@later_date_bump)
    
    # processing of dates is independent of whether the dates are in the data
    # or in the attributes
    setup do
      attrs = attrs(@iso_date, @later_iso_date, "reason")
      insertion_result = insert(attrs)
      complete = get_and_complete(insertion_result.id)
      
      [complete: complete, attrs: attrs]
    end
    
    test "A lack of any changes", %{complete: complete, attrs: attrs} do
      changeset = ServiceGap.changeset(complete, attrs)
      assert changeset.valid?
      assert changeset.changes == %{}
      # To be really explicit:
      assert_span_has_not_been_added(changeset)
    end

    test "in-service date is new", %{complete: complete, attrs: attrs} do
      new_attrs = %{attrs | in_service_date: @iso_date_bump}
      %{changes: changes} = changeset = ServiceGap.changeset(complete, new_attrs)
      assert changeset.valid?
      assert changes.in_service_date == @date_bump
      refute changes[:out_of_service_date]
      assert changes.span == Datespan.customary(@date_bump, @later_date)
    end


    test "out-of-service date is new", %{complete: complete, attrs: attrs} do
      new_attrs = %{attrs | out_of_service_date: @later_iso_date_bump}
      %{changes: changes} = changeset = ServiceGap.changeset(complete, new_attrs)
      assert changeset.valid?
      assert changes.out_of_service_date == @later_date_bump
      refute changes[:in_service_date]
      assert changes.span == Datespan.customary(@date, @later_date_bump)
    end


    test "date mismatches happen even if only in_service date changes",
      %{complete: complete, attrs: attrs} do
      
      new_attrs = %{attrs | in_service_date: @later_iso_date}
      %{changes: changes} = changeset = ServiceGap.changeset(complete, new_attrs)
      refute changeset.valid?
      assert changes.in_service_date == @later_date
      refute changes[:out_of_service_date]
      refute changes[:span]
      
      assert ToDate.misorder_error_message in errors_on(changeset).out_of_service_date
    end

    test "date mismatches happen even if only out_of_service date changes",
      %{complete: complete, attrs: attrs} do
      
      new_attrs = %{attrs | out_of_service_date: @iso_date}
      %{changes: changes} = changeset = ServiceGap.changeset(complete, new_attrs)
      refute changeset.valid?
      assert changes.out_of_service_date == @date
      refute changes[:in_service_date]
      refute changes[:span]
      
      assert ToDate.misorder_error_message in errors_on(changeset).out_of_service_date
    end
  end
  
  describe "retrieval gaps are manipulated via animals" do
    setup do
      animal_id = Available.animal_id
      attrs = attrs(@iso_date, @iso_date_bump, "reason", animal_id: animal_id)
      insertion_result = insert(attrs)
      complete_gap = get_and_complete(insertion_result.id)
      complete_animal = AnimalApi.showable!(animal_id, @institution)
      
      [complete_gap: complete_gap, complete_animal: complete_animal]
    end
    
    test "insertion of new value",
      %{complete_gap: complete_gap, complete_animal: complete_animal} do

      new_gap_params = %{in_service_date: @later_iso_date,
                         out_of_service_date: @later_iso_date_bump,
                         reason: "addition"
                        }

      animal_update_attrs =
        same_animal_with_service_gap_params(complete_animal, [
              form_params_for_existing(complete_gap),
              new_gap_params
            ])

      changeset = Animal.update_changeset(complete_animal, animal_update_attrs)
      assert [old_sg_changeset, new_sg_changeset] = changeset.changes.service_gaps

      assert_nothing_done_for = fn (service_gap_changeset) ->
        assert service_gap_changeset.valid?
        assert service_gap_changeset.changes == %{}
      end

      assert_nothing_done_for.(old_sg_changeset)

      assert_valid_changeset_with = fn changeset, opts ->
        optmap = Enum.into(opts, %{})

        assert changeset.valid?
        # this should really map over the optmap
        assert changeset.changes.reason == optmap.reason
        assert changeset.changes.span == optmap.span
      end

      assert_valid_changeset_with.(new_sg_changeset,
        reason: "addition",
        span: Datespan.customary(@later_date, @later_date_bump)
      )

      assert {:ok, %{service_gaps: [old, new]}} = Sql.update(changeset, @institution)

      assert old == complete_gap
      
      assert is_integer(new.id)
      assert new.in_service_date == @later_date
      assert new.out_of_service_date == @later_date_bump
      assert new.reason == "addition"
      assert new.span == Datespan.customary(@later_date, @later_date_bump)
    end
  end

  defp assert_span_has_not_been_added(%{changes: changes}), 
    do: refute changes[:span]

  defp insert(attrs) do
    %ServiceGap{}
    |> ServiceGap.changeset(attrs)
    |> Sql.insert!(@institution)
  end

  defp get_and_complete(id) do
    ServiceGap
    |> Sql.get(id, @institution)
    |> ServiceGap.complete_fields
  end

  defp attrs(in_service_date, out_of_service_date, reason, opts \\ []) do
    defaults = %{animal_id: Available.animal_id}
    optmap = Enum.into(opts, defaults)
    %{animal_id: optmap.animal_id,
      in_service_date: in_service_date,
      out_of_service_date: out_of_service_date,
      reason: reason}
  end

  defp form_params_for_existing(service_gap) do 
    %{id: service_gap.id,
      in_service_date: service_gap.in_service_date,
      out_of_service_date: service_gap.out_of_service_date,
      reason: service_gap.reason}
  end


  defp same_animal_with_service_gap_params(animal, service_gaps) do
    IO.puts("TODO note: never")
    %{id: animal.id,
      name: animal.name,
      in_service_date: Date.to_iso8601(animal.in_service_date),
      # This will sometimes fail because the animal may have a "never"
      # out-of-service date.
      out_of_service_date: Date.to_iso8601(animal.out_of_service_date),
      lock_version: animal.lock_version,
      service_gaps: service_gaps
    }
  end
end
