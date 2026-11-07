{ lib
, python3
, gtk4
, libadwaita
, gobject-introspection
, wrapGAppsHook4
}:

python3.pkgs.buildPythonApplication rec {
  pname = "fan-control";
  version = "1.0.0";
  format = "other";

  src = ./.;

  nativeBuildInputs = [
    gobject-introspection
    wrapGAppsHook4
  ];

  buildInputs = [
    gtk4
    libadwaita
  ];

  propagatedBuildInputs = with python3.pkgs; [
    pygobject3
  ];

  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/python3/site-packages
    cp -r fanctl $out/lib/python3/site-packages/

    mkdir -p $out/bin
    cp app.py $out/bin/fan-control
    cp daemon.py $out/bin/fan-control-daemon
    cp cli.py $out/bin/fanctl
    chmod +x $out/bin/*

    mkdir -p $out/share/applications
    cp fan-control.desktop $out/share/applications/

    mkdir -p $out/share/dbus-1/system.d
    cp org.thinkpad.FanControl.conf $out/share/dbus-1/system.d/

    runHook postInstall
  '';

  preFixup = ''
    for prog in $out/bin/*; do
      makeWrapperArgs+=(
        "''${gappsWrapperArgs[@]}"
        --prefix PYTHONPATH : "$out/lib/python3/site-packages:$PYTHONPATH"
      )
      wrapProgram "$prog" "''${makeWrapperArgs[@]}"
    done
  '';

  meta = with lib; {
    description = "ThinkPad fan curve and thermal controller";
    platforms = platforms.linux;
    mainProgram = "fanctl";
  };
}
