defmodule AnacountsAPI.Schema.AccountsTypes do
  @moduledoc """
  Objects related to the `Anacounts.Account` module.
  """

  use Absinthe.Schema.Notation

  alias AnacountsAPI.Resolvers

  ## Entities

  @desc "A group of people"
  object :book do
    field(:id, :id)
    field(:name, :string)
    field(:inserted_at, :naive_datetime)

    field(:members, list_of(:book_member)) do
      resolve(&Resolvers.Auth.find_book_members/3)
    end

    field(:money_transfers, list_of(:money_transfer)) do
      resolve(&Resolvers.Transfers.find_book_transfers/3)
    end
  end

  @desc "One of the users attached to a book"
  object :book_member do
    # identification
    field(:id, :id)

    # TODO Replace with `field :user, :user`
    # display information
    field(:display_name, :string)

    field(:avatar_url, :string) do
      resolve(&Resolvers.Auth.get_profile_avatar_url/3)
    end

    # relation to book
    field(:role, :string)
  end

  ## Queries

  object :accounts_queries do
    @desc "Get a book belonging to authentified user"
    field :book, :book do
      arg(:id, non_null(:id))

      resolve(&Resolvers.Accounts.find_book/3)
    end

    @desc "Get all books belonging to authentified user"
    field :books, list_of(:book) do
      resolve(&Resolvers.Accounts.find_books/3)
    end
  end

  ## Mutations

  object :accounts_mutations do
    @desc "Creates a new book"
    field :create_book, :book do
      arg(:attrs, non_null(:book_input))

      resolve(&Resolvers.Accounts.do_create_book/3)
    end

    @desc "Delete an existing book"
    field :delete_book, :book do
      arg(:id, non_null(:id))

      resolve(&Resolvers.Accounts.do_delete_book/3)
    end

    field :invite_user, :book_member do
      arg(:book_id, non_null(:id))
      arg(:email, non_null(:string))

      resolve(&Resolvers.Accounts.do_invite_user/3)
    end
  end

  ## Input objects

  @desc "Used to make operations (insert, update) on books"
  input_object :book_input do
    field(:name, non_null(:string))
  end
end
