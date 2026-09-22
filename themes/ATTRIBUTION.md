# Theme attribution

Most palettes here were ported from [Omarchy](https://github.com/basecamp/omarchy)
with `omacos theme import`, which maps Omarchy's `colors.toml` onto ours,
derives the four ANSI colours Omarchy does not define, and generates a gradient
wallpaper from the palette.

**No wallpaper, preview or unlock image was copied from Omarchy.** Those are not
in every case the project's to relicense. Every background in this repository is
generated from its own palette by `omacos dev make-wallpaper`.

## Omarchy

```
MIT License

Copyright (c) David Heinemeier Hansson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## The palettes themselves

Omarchy's MIT licence covers Omarchy's derivation. Several palettes originate
with their own projects, which deserve the credit as much as Omarchy does:

| Theme | Origin |
|---|---|
| catppuccin-mocha, catppuccin-latte | [Catppuccin](https://github.com/catppuccin/catppuccin) |
| rose-pine-dawn | [Rosé Pine](https://rosepinetheme.com) |
| gruvbox | [gruvbox](https://github.com/morhetz/gruvbox) |
| nord | [Nord](https://www.nordtheme.com) |
| everforest | [Everforest](https://github.com/sainnhe/everforest) |
| kanagawa | [Kanagawa](https://github.com/rebelot/kanagawa.nvim) |
| flexoki-light | [Flexoki](https://stephango.com/flexoki) |
| tokyo-night | [Tokyo Night](https://github.com/folke/tokyonight.nvim) |

## Naming

Omarchy's `catppuccin` is Mocha, which we ship as `catppuccin-mocha`. Omarchy's
`rose-pine` uses the Dawn (light) palette; we already shipped a Rosé Pine Dawn
as `rose-pine-dawn`, so that import was dropped rather than ship two themes a
person cannot tell apart.
