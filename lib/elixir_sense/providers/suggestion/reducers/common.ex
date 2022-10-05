defmodule ElixirSense.Providers.Suggestion.Reducers.Common do
  @moduledoc false

  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Source
  alias ElixirSense.Core.State
  alias ElixirSense.Providers.Suggestion.Complete
  alias ElixirSense.Providers.Suggestion.Reducer

  @type attribute :: %{
          type: :attribute,
          name: String.t()
        }

  @type variable :: %{
          type: :variable,
          name: String.t()
        }

  @type func :: %{
          type: :function | :macro,
          visibility: :public | :private,
          name: String.t(),
          arity: non_neg_integer,
          def_arity: non_neg_integer,
          args: String.t(),
          args_list: [String.t()],
          origin: String.t(),
          summary: String.t(),
          spec: String.t(),
          snippet: String.t() | nil,
          metadata: map
        }

  @type mod :: %{
          type: :module,
          name: String.t(),
          subtype: ElixirSense.Core.Introspection.module_subtype(),
          summary: String.t(),
          metadata: map
        }

  @doc """
  A reducer that populates the context with the suggestions provided by
  the `ElixirSense.Providers.Suggestion.Complete` module.

  The suggestions are grouped by type and saved in the context under the
  `:common_suggestions_by_type` key and can be accessed by any reducer
  that runs after.

  Available suggestions:

    * Modules
    * Functions
    * Macros
    * Variables
    * Module attributes
    * Variable fields

  """
  def populate(hint, env, buffer_metadata, context, acc, opts \\ []) do
    text_before = context.text_before

    suggestions = find_mods_funcs(hint, env, buffer_metadata, text_before, opts)

    suggestions_by_type = Enum.group_by(suggestions, & &1.type)

    {:cont, Reducer.put_context(acc, :common_suggestions_by_type, suggestions_by_type)}
  end

  @doc """
  A reducer that adds suggestions of existing modules.

  Note: requires populate/5.
  """
  def add_modules(_hint, _env, _file_metadata, _context, acc) do
    add_suggestions(:module, acc)
  end

  @doc """
  A reducer that adds suggestions of existing functions.

  Note: requires populate/5.
  """
  def add_functions(_hint, _env, _file_metadata, _context, acc) do
    add_suggestions(:function, acc)
  end

  @doc """
  A reducer that adds suggestions of existing macros.

  Note: requires populate/5.
  """
  def add_macros(_hint, _env, _file_metadata, _context, acc) do
    add_suggestions(:macro, acc)
  end

  @doc """
  A reducer that adds suggestions of variable fields.

  Note: requires populate/5.
  """
  def add_fields(_hint, _env, _file_metadata, _context, acc) do
    add_suggestions(:field, acc)
  end

  @doc """
  A reducer that adds suggestions of existing module attributes.

  Note: requires populate/5.
  """
  def add_attributes(_hint, _env, _file_metadata, _context, acc) do
    add_suggestions(:attribute, acc)
  end

  @doc """
  A reducer that adds suggestions of existing variables.

  Note: requires populate/5.
  """
  def add_variables(_hint, _env, _file_metadata, _context, acc) do
    add_suggestions(:variable, acc)
  end

  defp add_suggestions(type, acc) do
    suggestions_by_type = Reducer.get_context(acc, :common_suggestions_by_type)
    list = Map.get(suggestions_by_type, type, [])
    {:cont, %{acc | result: acc.result ++ list}}
  end

  defp find_mods_funcs(
         hint,
         %State.Env{
           imports: imports,
           aliases: aliases,
           module: module,
           vars: vars,
           attributes: attributes,
           scope: scope,
           behaviours: behaviours
         },
         %Metadata{
           structs: structs,
           mods_funs_to_positions: mods_and_funs,
           specs: metadata_specs,
           types: metadata_types
         },
         text_before,
         opts
       ) do
    env = %Complete.Env{
      aliases: aliases,
      vars: vars,
      attributes: attributes,
      scope_module: module,
      imports: imports,
      mods_and_funs: mods_and_funs,
      specs: metadata_specs,
      structs: structs,
      types: metadata_types,
      scope: scope,
      behaviours: behaviours
    }

    hint =
      case Source.get_v12_module_prefix(text_before, module) do
        nil ->
          hint

        module_string ->
          # v1.2 alias syntax detected
          # prepend module prefix before running completion
          prefix = module_string <> "."
          prefix <> hint
      end

    hint =
      if String.starts_with?(hint, "__MODULE__") do
        hint |> String.replace_leading("__MODULE__", inspect(module))
      else
        hint
      end

    Complete.complete(hint, env, opts)
  end
end
