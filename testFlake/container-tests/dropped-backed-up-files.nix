{
  forEachDistro,
  system-manager,
  system,
  ...
}:

let
  configV2 = system-manager.lib.makeSystemConfig {
    modules = [
      {
        nixpkgs.hostPlatform = system;
        system-manager.allowAnyDistro = true;
      }
    ];
  };
in

forEachDistro "dropped-backed-up-files" {
  modules = [
    {
      environment.etc = {
        "replaced-test" = {
          text = "managed\n";
          replaceExisting = true;
        };
        "replaced-copy-test" = {
          text = "managed\n";
          mode = "0644";
          replaceExisting = true;
        };
      };
    }
  ];
  extraPathsToRegister = [ configV2 ];
  testScriptFunction =
    { toplevel, ... }:
    ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      machine.succeed("echo -n original > /etc/replaced-test")
      machine.succeed("echo -n original > /etc/replaced-copy-test")

      with subtest("the entry replaces the original and backs it up"):
          machine.activate()
          machine.succeed("test -L /etc/replaced-test")
          assert machine.succeed("cat /etc/replaced-test.system-manager-backup") == "original"
          assert machine.succeed("cat /etc/replaced-copy-test") == "managed\n"
          assert machine.succeed("cat /etc/replaced-copy-test.system-manager-backup") == "original"

      with subtest("dropping the entry restores the original"):
          machine.activate("${configV2}")
          machine.succeed("test -f /etc/replaced-test -a ! -L /etc/replaced-test")
          assert machine.succeed("cat /etc/replaced-test") == "original"
          machine.fail("test -e /etc/replaced-test.system-manager-backup")
          assert machine.succeed("cat /etc/replaced-copy-test") == "original"
          machine.fail("test -e /etc/replaced-copy-test.system-manager-backup")

      with subtest("adding it back backs up the original again"):
          machine.activate()
          machine.succeed("test -L /etc/replaced-test")
          assert machine.succeed("cat /etc/replaced-test.system-manager-backup") == "original"
          assert machine.succeed("cat /etc/replaced-copy-test.system-manager-backup") == "original"
    '';
}
