collection of tools to speed up work in godot

⚠️ very much made for my specific workflow so probably not what you're looking for ⚠️

auto script formatting:
- formats spaces `3+2*12`→`3 + 2 * 12` `var   a=3`→`var a = 3` `func a()->bool:`→`func a() -> bool:` (still buggy at times)
- formats numbers (`0.` → `0.0`, `.1` → `0.1`)
- ensures double empty lines between functions

script generation:
- <kbd>ctrl</kbd> + <kbd>:</kbd> to open code generation tools
  - set tool script
  - turn line into seperator comment
  - generate `const preload("path")` from `load("path")`
  - set class name to the PascalCase of the script name
  - some more but mostly temp stuff

scene formatting:
- automatically renames the root node of a scene to the PascalCase of the scene name (why can you even name these in godot)

pin run scenes:
- right click on the Run Current Scene to pin this scene or unpin. Will run the pinned scene instead
