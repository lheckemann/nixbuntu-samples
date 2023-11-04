{ vmTools }:
vmTools.makeImageFromDebDist {
  inherit (vmTools.debDistros.ubuntu2004x86_64) name fullName urlPrefix packagesLists;
  packages = vmTools.debDistros.ubuntu2004x86_64.packages ++ ["systemd" "zsh" "vim"];
}
