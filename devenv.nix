{ pkgs, lib, config, inputs, ... }:

{
  env = {
    PROJECT_NAME = "sidebard";
  };

  packages = [
    pkgs.git
    pkgs.nim
    pkgs.nimble
    pkgs.just
    pkgs.jq
  ];

  languages = {};

  scripts = {
    hello.exec = ''
      echo "sidebard development environment"
    '';

    test.exec = ''
      nimble test
    '';

    build.exec = ''
      nimble build
    '';
  };

  enterShell = ''
    hello
    echo "project: $PROJECT_NAME"
    git --version
    nim --version | head -n 1
    nimble --version
    echo "quick commands: build | test"
  '';

  enterTest = ''
    echo "Running sidebard devenv checks"
    git --version | grep --color=auto "${pkgs.git.version}"
    nim --version >/dev/null
    nimble --version >/dev/null
    nimble build >/dev/null
  '';
}
