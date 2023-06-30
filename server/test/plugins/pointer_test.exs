defmodule Server.Plugins.PointerTest do
  use ExUnit.Case, async: true
  alias Server.Plugins.Pointer

  describe "resolve/3" do
    test "it resolves basic pointers" do
      object = %{"a" => 1}
      assert Pointer.resolve(object, "/a", []) == {:ok, 1}

      object = [1, 2, 3]
      assert Pointer.resolve(object, "/0", []) == {:ok, 1}
      assert Pointer.resolve(object, "/1", []) == {:ok, 2}
      assert Pointer.resolve(object, "/2", []) == {:ok, 3}

      object = %{"a" => [1, 2, 3]}
      assert Pointer.resolve(object, "/a/0", []) == {:ok, 1}
      assert Pointer.resolve(object, "/a/1", []) == {:ok, 2}
      assert Pointer.resolve(object, "/a/2", []) == {:ok, 3}

      object = %{"a" => %{"b" => 1}}
      assert Pointer.resolve(object, "/a/b", []) == {:ok, 1}

      object = %{"a" => %{"b" => [1, 2, 3]}}
      assert Pointer.resolve(object, "/a/b/0", []) == {:ok, 1}
    end

    test "it resolves escaped characters" do
      object = %{"a/b" => 1}
      assert Pointer.resolve(object, "/a~1b", []) == {:ok, 1}

      object = %{"a~1b" => 1}
      assert Pointer.resolve(object, "/a~01b", []) == {:ok, 1}

      object = %{"a~0b" => 1}
      assert Pointer.resolve(object, "/a~00b", []) == {:ok, 1}

      object = %{"~" => 1, "/" => 2}
      assert Pointer.resolve(object, "/~0", []) == {:ok, 1}
      assert Pointer.resolve(object, "/~1", []) == {:ok, 2}
    end

    test "it resolves paths with many escaped characters" do
      object = %{"a/b~0c/d" => 1}
      assert Pointer.resolve(object, "/a~1b~00c~1d", []) == {:ok, 1}
    end
  end
end
