{
  forEachDistro,
  ...
}:

forEachDistro "tmpfiles-replace-existing" {
  modules = [
    {
      environment.etc."tmpfiles.d/50-replaced.conf" = {
        text = "d /run/replaced-test 0755 root root -";
        replaceExisting = true;
      };
    }
  ];
  testScriptFunction =
    { toplevel, ... }:
    ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      machine.succeed("echo '# original' > /etc/tmpfiles.d/50-replaced.conf")
      machine.activate()

      machine.succeed("test -L /etc/tmpfiles.d/50-replaced.conf")
      machine.succeed("test -d /run/replaced-test")
    '';
}
