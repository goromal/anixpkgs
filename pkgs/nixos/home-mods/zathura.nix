{ pkgs, config, lib, ... }:
with pkgs;
{
    home.packages = [
        zathura
    ];

    home.file = {
        ".config/zathura/zathurarc".source = ../res/zathurarc;
    };
}
