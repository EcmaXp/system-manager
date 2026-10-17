{
  forEachDistro,
  ...
}:

# suid-sgid-wrappers is ordered after userborn.service, so systemd lists a
# disabled userborn as "not-found".
forEachDistro "userborn-disabled" {
  modules = [
    {
      services.userborn.enable = false;
    }
  ];
  testScriptFunction =
    { toplevel, ... }:
    ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      logs = machine.succeed("${toplevel}/bin/activate 2>&1")
      for line in logs.split("\n"):
          assert "ERROR" not in line, line
      machine.wait_for_unit("system-manager.target")
    '';
}
