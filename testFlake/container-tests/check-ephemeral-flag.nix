{
  forEachDistro,
  ...
}:

forEachDistro "check-ephemeral-flag" {
  modules = [
    {
      environment.etc = {
        "a/bar" = {
          text = "bar";
          mode = "0700";
          user = "root";
          group = "root";
        };
      };
      systemd.tmpfiles.rules = [ "d /run/ephemeral-test 0755 root root -" ];
      systemd.services.ephemeral-test = {
        wantedBy = [ "system-manager.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = "true";
      };
    }
  ];
  testScriptFunction =
    { toplevel, ... }:
    ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      def activate_ephemeral():
          logs = machine.succeed("${toplevel}/bin/activate --ephemeral 2>&1")
          for line in logs.split("\n"):
              assert "ERROR" not in line, line
          machine.wait_for_unit("system-manager.target")

      machine.succeed("printf '[Service]\\nExecStart=/bin/true\\n' > /run/systemd/system/sentinel.service")

      with subtest("ephemeral activation stays under /run"):
          activate_ephemeral()
          assert machine.file("/run/etc/a/bar").contains("bar")
          machine.fail("test -e /etc/a/bar")
          machine.succeed("test -L /run/systemd/system/ephemeral-test.service")
          machine.fail("test -e /etc/systemd/system/ephemeral-test.service")
          machine.succeed("systemctl is-active ephemeral-test.service")
          machine.succeed("test -d /run/ephemeral-test")

      with subtest("existing runtime units are kept"):
          machine.succeed("test -d /run/systemd/system -a ! -L /run/systemd/system")
          machine.succeed("test -f /run/systemd/system/sentinel.service")
          machine.succeed("systemctl list-units --no-pager")

      with subtest("a runtime unit dir symlink left by older versions is healed"):
          machine.succeed("mkdir -p /run/etc/systemd && rm -rf /run/etc/systemd/system && mv /run/systemd/system /run/etc/systemd/system && ln -s /run/etc/systemd/system /run/systemd/system")
          activate_ephemeral()
          machine.succeed("test -d /run/systemd/system -a ! -L /run/systemd/system")
          machine.succeed("systemctl list-units --no-pager")
    '';
}
