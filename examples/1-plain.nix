{ vmTools, ... }:
let distro = vmTools.debDistros.ubuntu2004x86_64; in
vmTools.makeImageFromDebDist {
  inherit (distro) name fullName urlPrefix packagesLists;
  packages = distro.packages ++ ["systemd" "zsh" "vim"];
}
