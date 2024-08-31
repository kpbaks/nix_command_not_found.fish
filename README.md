# nix_command_not_found.fish
Colorize the output of `/run/current-system/sw/bin/command-not-found` and make it more informative!


## Dependencies

- `python` Any version `>= 3.0.0` should be sufficient as the only module used is [`difflib`](https://docs.python.org/3/library/difflib.html#difflib.get_close_matches)
- [`NixOS`](https://nixos.org/) as per the description this plugin is only intended for fish installations on NixOS.


## Installation

### [`fisher`](https://github.com/jorgebucaran/fisher)

```fish
fisher install kpbaks/nix_command_not_found.fish
```


