defmodule AnacountsAPI.Schema.TransfersTypesTest do
  use AnacountsAPI.ConnCase

  import Anacounts.AuthFixtures
  import Anacounts.AccountsFixtures
  import Anacounts.TransfersFixtures
  import AnacountsAPI.Helpers.Tests, only: [test_logged_in: 2]

  alias AnacountsAPI.Schema.CustomTypes

  describe "query: money_transfer" do
    @money_transfer_query """
    query GetMoneyTransfer($id: ID!) {
      moneyTransfer(id: $id) {
        id

        label
        amount
        type
        date

        balanceParams {
          meansCode
          params
        }

        peers {
          id
          weight

          member {
            id
          }
        }
      }
    }
    """

    setup :setup_user_fixture
    setup :setup_log_user_in

    setup :setup_book_fixture
    setup :setup_book_member_fixture
    setup :setup_money_transfer_fixture

    test "returns the money transfer", %{conn: conn, money_transfer: money_transfer} do
      # TODO add peers

      conn =
        post(conn, "/", %{
          "query" => @money_transfer_query,
          "variables" => %{"id" => money_transfer.id}
        })

      assert json_response(conn, 200) == %{
               "data" => %{
                 "moneyTransfer" => %{
                   "amount" => valid_money_transfer_amount() |> CustomTypes.serialize_money(),
                   "id" => to_string(money_transfer.id),
                   "date" => valid_money_transfer_date() |> DateTime.to_iso8601(),
                   "label" => valid_money_transfer_label(),
                   "type" => valid_money_transfer_type() |> to_string() |> String.upcase(),
                   "balanceParams" => %{
                     "meansCode" => "DIVIDE_EQUALLY",
                     "params" => %{}
                   },
                   "peers" => []
                 }
               }
             }
    end

    test "return not found if user isn't member of the book", %{
      conn: conn,
      money_transfer: money_transfer
    } do
      other_user = user_fixture()

      conn = log_user_in(conn, other_user)

      conn =
        post(conn, "/", %{
          "query" => @money_transfer_query,
          "variables" => %{"id" => money_transfer.id}
        })

      assert json_response(conn, 200) == %{
               "data" => %{"moneyTransfer" => nil},
               "errors" => [
                 %{
                   "locations" => [%{"column" => 3, "line" => 2}],
                   "message" => "Not found",
                   "path" => ["moneyTransfer"]
                 }
               ]
             }
    end
  end

  describe "mutation: create_money_transfer" do
    @create_money_transfer_mutation """
    mutation CreateMoneyTransfer($attrs: MoneyTransferCreationInput!) {
      createMoneyTransfer(attrs: $attrs) {
        amount
        type
        date

        tenant {
          id
        }

        balanceParams {
          meansCode
          params
        }

        peers {
          weight
        }
      }
    }
    """

    setup :setup_user_fixture
    setup :setup_log_user_in

    setup :setup_book_fixture
    setup :setup_book_member_fixture

    test "create a money transfer", %{conn: conn, book: book, book_member: book_member} do
      conn =
        post(conn, "/", %{
          "query" => @create_money_transfer_mutation,
          "variables" => %{
            "attrs" => %{
              "bookId" => book.id,
              "tenantId" => book_member.id,
              "label" => "Ha, whatever",
              "amount" => "199.9/EUR",
              "date" => "2022-02-10T23:04:12Z",
              "type" => "INCOME",
              "peers" => [
                %{"memberId" => book_member.id}
              ]
            }
          }
        })

      assert json_response(conn, 200) == %{
               "data" => %{
                 "createMoneyTransfer" => %{
                   "amount" => "19990/EUR",
                   "date" => "2022-02-10T23:04:12Z",
                   "type" => "INCOME",
                   "tenant" => %{
                     "id" => to_string(book_member.id)
                   },
                   "balanceParams" => %{
                     "meansCode" => "DIVIDE_EQUALLY",
                     "params" => %{}
                   },
                   "peers" => [
                     %{"weight" => "1"}
                   ]
                 }
               }
             }
    end

    test "creates a money transfer for another user", %{
      conn: conn,
      book: book,
      book_member: book_member
    } do
      other_user = user_fixture()
      other_member = book_member_fixture(book, other_user)

      conn =
        post(conn, "/", %{
          "query" => @create_money_transfer_mutation,
          "variables" => %{
            "attrs" => %{
              "bookId" => book.id,
              "tenantId" => other_member.id,
              "label" => "Ha, whatever",
              "amount" => "199.9/EUR",
              "date" => "2022-02-10T23:04:12Z",
              "type" => "INCOME",
              "balanceParams" => %{
                # TODO Change it to another mode
                "meansCode" => "DIVIDE_EQUALLY",
                "params" => "{}"
              },
              "peers" => [
                %{"memberId" => book_member.id}
              ]
            }
          }
        })

      assert json_response(conn, 200) == %{
               "data" => %{
                 "createMoneyTransfer" => %{
                   "amount" => "19990/EUR",
                   "date" => "2022-02-10T23:04:12Z",
                   "type" => "INCOME",
                   "tenant" => %{
                     "id" => to_string(other_member.id)
                   },
                   "balanceParams" => %{
                     "meansCode" => "DIVIDE_EQUALLY",
                     "params" => %{}
                   },
                   "peers" => [
                     %{"weight" => "1"}
                   ]
                 }
               }
             }
    end

    test "uses today as default date", %{conn: conn, book: book, book_member: book_member} do
      conn =
        post(conn, "/", %{
          "query" => @create_money_transfer_mutation,
          "variables" => %{
            "attrs" => %{
              "bookId" => book.id,
              "tenantId" => book_member.id,
              "label" => "Here's a transfer label",
              "amount" => "399/USD",
              "type" => "REIMBURSEMENT"
            }
          }
        })

      assert response = json_response(conn, 200)
      assert response["data"]["createMoneyTransfer"]["date"]
    end

    test "cannot create for a book the user isn't member of", %{
      conn: conn,
      book_member: book_member
    } do
      other_user = user_fixture()
      other_book = book_fixture(other_user)

      conn =
        post(conn, "/", %{
          "query" => @create_money_transfer_mutation,
          "variables" => %{
            "attrs" => %{
              "bookId" => other_book.id,
              "tenantId" => book_member.id,
              "label" => "Look at me !",
              "amount" => "199/AED",
              "type" => "PAYMENT",
              "peers" => []
            }
          }
        })

      assert json_response(conn, 200) == %{
               "data" => %{"createMoneyTransfer" => nil},
               "errors" => [
                 %{
                   "locations" => [%{"column" => 3, "line" => 2}],
                   "message" => "Not found",
                   # TODO path could be enhanced to ["createMoneyTransfer", "bookId"]
                   "path" => ["createMoneyTransfer"]
                 }
               ]
             }
    end

    test_logged_in(@create_money_transfer_mutation, %{
      "attrs" => %{
        "bookId" => 0,
        "tenantId" => 0,
        "label" => "label",
        "amount" => "0/EUR",
        "type" => "INCOME"
      }
    })
  end

  describe "mutation: update_money_transfer" do
    @update_money_transfer_mutation """
    mutation UpdateMoneyTransfer($transferId: ID!, $attrs: MoneyTransferUpdateInput!) {
      updateMoneyTransfer(transferId: $transferId, attrs: $attrs) {
        label
        amount
        type
        date

        tenant {
          id
        }

        peers {
          weight
        }
      }
    }
    """

    setup :setup_user_fixture
    setup :setup_log_user_in

    setup :setup_book_fixture
    setup :setup_book_member_fixture
    setup :setup_money_transfer_fixture

    test "updates the money transfer", %{conn: conn, book: book, money_transfer: money_transfer} do
      other_user = user_fixture()
      other_member = book_member_fixture(book, other_user)

      conn =
        post(conn, "/", %{
          "query" => @update_money_transfer_mutation,
          "variables" => %{
            "transferId" => money_transfer.id,
            "attrs" => %{
              "label" => "hey, here's a label",
              "date" => "2024-04-04T04:04:04Z",
              "amount" => "280.00/ALL",
              "tenantId" => other_member.id,
              "peers" => [
                %{"memberId" => other_member.id, "weight" => "3"}
              ]
            }
          }
        })

      assert json_response(conn, 200) == %{
               "data" => %{
                 "updateMoneyTransfer" => %{
                   "label" => "hey, here's a label",
                   "amount" => "28000/ALL",
                   "type" => "PAYMENT",
                   "date" => "2024-04-04T04:04:04Z",
                   "tenant" => %{
                     "id" => to_string(other_member.id)
                   },
                   "peers" => [
                     %{"weight" => "3"}
                   ]
                 }
               }
             }
    end

    test "cannot update a transfer belonging to book the user isn't member of", %{
      conn: conn,
      money_transfer: money_transfer
    } do
      other_user = user_fixture()
      conn = log_user_in(conn, other_user)

      conn =
        post(conn, "/", %{
          "query" => @update_money_transfer_mutation,
          "variables" => %{
            "transferId" => money_transfer.id,
            "attrs" => %{
              "amount" => "9810/EEK",
              "date" => "2025-05-05T05:05:05Z"
            }
          }
        })

      assert json_response(conn, 200) == %{
               "data" => %{"updateMoneyTransfer" => nil},
               "errors" => [
                 %{
                   "locations" => [%{"column" => 3, "line" => 2}],
                   "message" => "Not found",
                   # TODO path could be enhanced to ["createMoneyTransfer", "bookId"]
                   "path" => ["updateMoneyTransfer"]
                 }
               ]
             }
    end

    test_logged_in(@update_money_transfer_mutation, %{"transferId" => 0, "attrs" => %{}})
  end

  describe "mutation: delete_money_transfer" do
    @delete_money_transfer_mutation """
    mutation DeleteMoneyTransfer($transferId: ID!) {
      deleteMoneyTransfer(transferId: $transferId) {
        id
      }
    }
    """

    setup :setup_user_fixture
    setup :setup_log_user_in

    setup :setup_book_fixture
    setup :setup_book_member_fixture
    setup :setup_money_transfer_fixture

    test "deletes the money transfer", %{conn: conn, money_transfer: money_transfer} do
      conn =
        post(conn, "/", %{
          "query" => @delete_money_transfer_mutation,
          "variables" => %{
            "transferId" => money_transfer.id
          }
        })

      assert json_response(conn, 200) == %{
               "data" => %{
                 "deleteMoneyTransfer" => %{
                   "id" => to_string(money_transfer.id)
                 }
               }
             }
    end

    test "cannot delete if the user isn't a member", %{conn: conn, money_transfer: money_transfer} do
      other_user = user_fixture()

      conn = log_user_in(conn, other_user)

      conn =
        post(conn, "/", %{
          "query" => @delete_money_transfer_mutation,
          "variables" => %{
            "transferId" => money_transfer.id
          }
        })

      assert json_response(conn, 200) == %{
               "data" => %{"deleteMoneyTransfer" => nil},
               "errors" => [
                 %{
                   "locations" => [%{"column" => 3, "line" => 2}],
                   "message" => "Not found",
                   "path" => ["deleteMoneyTransfer"]
                 }
               ]
             }
    end

    test_logged_in(@delete_money_transfer_mutation, %{"transferId" => 0})
  end
end
