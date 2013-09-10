archlinux
=========

[Indie Box Project](http://indieboxproject.org/) code for ArchLinux. So far, it's just a scaffold.

There are two packages here:
 * indie-box: to be installed on the device on which applications will run
 * indie-box-dev: to be installed on the host on which applications will be built

How to use:
```
    cd indie-box
    makepkg -c
    sudo pacman -U indie-box-*.pkg.tar.xz
    indie-box-admin --help
```

```
    cd indie-box-dev
    makepkg -c
    sudo pacman -U indie-box-dev-*.pkg.tar.xz
    indie-box-build --help
```

Note this only works on ArchLinux http://archlinux.org/ or http://archlinuxarm.org/

For more info:
 * Project website: http://indieboxproject.org/
 * Project documentation: http://indieboxproject.org/wiki/ (including more detailed
   instructions for devices such as the Raspberry Pi)
 * Twitter: @indieboxproject

Want to help? We appreciate it. See http://indieboxproject.org/blog/contributing/
