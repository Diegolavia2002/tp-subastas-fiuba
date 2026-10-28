defmodule SistemaSubastas.CLITest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  test "la CLI se recupera de un comando incorrecto" do
    {:ok, manager} = SistemaSubastas.start_link()

    output =
      capture_io(fn ->
        assert :continue = SistemaSubastas.CLI.execute(manager, "comando_que_no_existe")
        assert :continue = SistemaSubastas.CLI.execute(manager, "crear \"Mesa\" 100 5000")
        assert :continue = SistemaSubastas.CLI.execute(manager, "consultar 1")
      end)

    assert output =~ "ERROR comando_invalido"
    assert output =~ "OK subasta=1"
    assert output =~ "estado=activa"
    SistemaSubastas.stop(manager)
  end
end
