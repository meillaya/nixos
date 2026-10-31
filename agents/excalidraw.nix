# Agent rules for hand-drawn diagrams with the Excalidraw CLI.
#
# Data only. Nothing imports this file and no host evaluates it. An agent reads
# the strings, or a settings module imports the attrset and appends
# `instructions` to its prompt.

let
  instructions = ''
    ## Drawing diagrams with the Excalidraw CLI

    Use the packaged CLI in `pkgs/excalidraw-cli`. It is installed as
    `excalidraw` on the configured hosts, and the flake exposes it as
    `excalidraw-cli`. Build a fresh copy with `nix build .#excalidraw-cli`.
    Render every scene to PNG and inspect the PNG before you call the figure
    done.

    ### Scene format

    Write an `.excalidraw` JSON scene. The top level has `type`, `version`,
    `source`, `elements`, `appState`, and `files`. Set
    `appState.viewBackgroundColor` to `#ffffff`. Every element needs the full
    Excalidraw field set: `id`, `type`, `x`, `y`, `width`, `height`, `angle`,
    `strokeColor`, `backgroundColor`, `fillStyle`, `strokeWidth`, `strokeStyle`,
    `roughness`, `opacity`, `groupIds`, `frameId`, `roundness`, `seed`, `version`,
    `versionNonce`, `isDeleted`, `boundElements`, `updated`, `link`, and `locked`.

    Bind text to a shape. The shape carries
    `boundElements: [{ type: "text", id: "..." }]` and the text carries
    `containerId` set to the shape id, `textAlign: "center"`,
    `verticalAlign: "middle"`, and `fontFamily: 1`. Use explicit newlines for
    line breaks. Keep each label to six words or fewer.

    Draw arrows as `type: "arrow"` with `points: [[0,0],[dx,dy]]`,
    `startArrowhead: null`, and `endArrowhead: "arrow"`. Place a separate text
    element near the midpoint for the label. Do not rely on arrow bindings for a
    static render.

    ### Hand-drawn style

    Set `roughness: 2`, `fillStyle: "hachure"`, `strokeWidth: 2`,
    `strokeStyle: "solid"`, and `fontFamily: 1` on every shape and text element.
    Use a white background. Do not use gradients, shadows, 3D effects, clip art,
    emoji, or embedded images.

    Use the palette below. Strokes carry the meaning and fills stay pale.

    | Role | Stroke | Fill |
    |---|---|---|
    | Input, compiler | `#1971c2` | `#d0ebff` |
    | CUDA | `#e8590c` | `#ffe8cc` |
    | HIP / ROCm | `#2f9e44` | `#d3f9d8` |
    | Runtime, shared code | `#9c36b5` | `#f3d9fa` |
    | Analysis, cache | `#f08c00` | `#fff3bf` |
    | Risk, regression | `#e03131` | `#ffe3e3` |
    | Model, simulator | `#0c8599` | `#c5f6fa` |
    | Neutral | `#495057` | `#f1f3f5` |

    ### Composition

    One figure makes one claim. Lead the eye from left to right. Put the measured
    or generated result at the bottom when the figure has two panels. Leave 40
    scene units of margin. Limit the figure to three columns and about twelve
    boxes. Label every arrow and put the label near the arrow.

    Use direct labels instead of a legend when the labels fit. Mark projected
    numbers as projected and measured numbers as measured. A performance figure
    carries the hardware, the shape, and the source.

    ### Size

    For a figure that lands at 6.5 inches wide, use a scene 1400 to 1600 units
    wide and fonts of 20 to 24 units for body text, 30 to 34 for the title, and
    16 to 18 for notes. Below 18 units the PNG is hard to read on a page. If a
    label does not fit, shorten it or split the figure. Do not shrink the font.

    ### Render and inspect

    ```bash
    nix build .#excalidraw-cli
    ./result/bin/excalidraw render docs/figures/example.excalidraw \
      --out docs/figures/example.png \
      --scale 2 --max-width 3200 \
      --browser-path "$EXCALIDRAW_BROWSER_PATH"
    ```

    On Linux, `nix run .#excalidraw-cli-browser -- render ...` supplies Chromium.
    On macOS, set `EXCALIDRAW_BROWSER_PATH` to a Chrome or Chromium binary. The
    installed `excalidraw` command on Linux already points at Chrome.

    Inspect the PNG at 100% and at the width it will appear in the document.
    Check four things: text stays inside its box, arrows do not cross text,
    every arrow has a label, and the smallest text is readable at page width.
    Render again after every edit.

    ### Files

    Keep the scene and the PNG together:
    `docs/figures/<name>.excalidraw` and `docs/figures/<name>.png`. When the
    geometry is generated, keep the generator next to them and make the scene
    reproducible. Do not edit a generated PNG by hand.

    ### Do not

    - Do not draw a directory tree unless the figure is about the directory tree.
    - Do not put more than one claim in a figure.
    - Do not use a colour without a role in the palette.
    - Do not use text smaller than 16 scene units.
    - Do not use an em dash in a label.
    - Do not ship a figure you have not rendered and inspected.
  '';
in
{
  inherit instructions;

  palette = {
    ink = "#1e1e1e";
    muted = "#5c5f66";
    compiler = {
      stroke = "#1971c2";
      fill = "#d0ebff";
    };
    cuda = {
      stroke = "#e8590c";
      fill = "#ffe8cc";
    };
    hip = {
      stroke = "#2f9e44";
      fill = "#d3f9d8";
    };
    runtime = {
      stroke = "#9c36b5";
      fill = "#f3d9fa";
    };
    analysis = {
      stroke = "#f08c00";
      fill = "#fff3bf";
    };
    risk = {
      stroke = "#e03131";
      fill = "#ffe3e3";
    };
    model = {
      stroke = "#0c8599";
      fill = "#c5f6fa";
    };
    neutral = {
      stroke = "#495057";
      fill = "#f1f3f5";
    };
  };

  defaults = {
    sceneWidth = 1520;
    sceneHeight = 940;
    margin = 40;
    roughness = 2;
    fillStyle = "hachure";
    strokeWidth = 2;
    fontFamily = 1;
    background = "#ffffff";
    fontSize = {
      title = 32;
      body = 22;
      note = 18;
    };
  };

  render = {
    scale = 2;
    maxWidth = 3200;
    maxHeight = 2000;
    browserEnv = "EXCALIDRAW_BROWSER_PATH";
    outputDir = "docs/figures";
  };

  checklist = [
    "The figure makes one claim."
    "Every box label fits inside its box."
    "Every arrow has a label near the arrow."
    "No arrow crosses text."
    "The smallest text is readable at page width."
    "Projected numbers are marked as projected."
    "The palette role matches the meaning."
    "The scene and the PNG are both present."
  ];
}
