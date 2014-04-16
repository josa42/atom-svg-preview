# SVG Preview package

Show the rendered SVG to the right of the current editor.

It can be activated from the editor using the `cmd-alt-v` key-binding and is
currently enabled for `.xml` and `.svg` files.

![Demo screenshot](https://f.cloud.github.com/assets/69169/2290250/c35d867a-a017-11e3-86be-cd7c5bf3ff9b.gif)

## Installation note

Atom has renamed its bundled `node` to `node_darwin_x64`, so apm can't (as of Atom 0.89) get dependencies in some cases. Workarounds:

    cd /Applications/Atom.app/Contents/Resources//app/apm/node_modules/atom-package-manager/bin
    ln -s node_darwin_x64 node

or have `node` installed (e.g via homebrew) and run `atom` from the command line (this way it inherits `PATH`) instead of from the Atom.app.
