# nix_command_not_found.fish
Colorize the output of `/run/current-system/sw/bin/command-not-found` and make it more informative!

<!-- <p align=center><h2>Before</h2> </p> -->
### Before

![before](https://github.com/user-attachments/assets/a67e9282-5849-430d-81d8-e5d9a613133a)

### After

![after](https://github.com/user-attachments/assets/22b18793-8e05-4d48-9356-465078e5fd11)


## Dependencies

- `python` Any version `>= 3.0.0` should be sufficient as the only module used is [`difflib`](https://docs.python.org/3/library/difflib.html#difflib.get_close_matches)
- [`NixOS`](https://nixos.org/) as per the description this plugin is only intended for fish installations on NixOS.


## Installation

### [`fisher`](https://github.com/jorgebucaran/fisher)

```fish
fisher install kpbaks/nix_command_not_found.fish
```

### Manual

Copy `./conf.d/nix_command_not_found.fish` into `$XDG_CONFIG_HOME/fish/conf.d/`
