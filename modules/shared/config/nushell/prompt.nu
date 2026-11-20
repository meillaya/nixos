# Nushell prompt in the Powerlevel10k lean style, drawn with the Catppuccin
# Mocha palette: grey frame, OS icon, blue directory, green Git status, and a
# right prompt with direnv, the Nix shell, and the clock. The retained p10k.zsh
# is the Pure profile; this file matches the lean profile that zsh shows
# interactively.

# Catppuccin Mocha. Replace these hex values with another flavor if needed.
def p10k-palette []: nothing -> record {
  {
    frame: "#6c7086"
    text: "#cdd6f4"
    dir: "#89b4fa"
    anchor: "#b4befe"
    shortened: "#7f849c"
    git: "#a6e3a1"
    dirty: "#fab387"
    untracked: "#89dceb"
    conflict: "#f38ba8"
    direnv: "#f9e2af"
    nix: "#cba6f7"
    clock: "#94e2d5"
    ok: "#a6e3a1"
    fail: "#f38ba8"
  }
}

def p10k-rgb [hex: string]: nothing -> string {
  let red = ($hex | str substring 1..2 | into int --radix 16)
  let green = ($hex | str substring 3..4 | into int --radix 16)
  let blue = ($hex | str substring 5..6 | into int --radix 16)
  $"\e[38;2;($red);($green);($blue)m"
}

def p10k-color [name: string, text: string]: nothing -> string {
  (p10k-rgb (p10k-palette | get $name)) + $text + "\e[0m"
}

def p10k-color-bold [name: string, text: string]: nothing -> string {
  "\e[1m" + (p10k-rgb (p10k-palette | get $name)) + $text + "\e[0m"
}

def p10k-os-icon []: nothing -> string {
  if ($nu.os-info.name == "macos") {
    "\u{F179}"
  } else if ("/etc/NIXOS" | path exists) {
    "\u{F313}"
  } else {
    "\u{F17C}"
  }
}

# The directory is shown relative to the home directory. The last segment, the
# first absolute segment, and any segment holding a Git repository are anchors,
# which p10k draws bold in the anchor color. A path over 80 columns is
# shortened with the shortest unique prefix of each middle segment, the shape
# p10k's truncate_to_unique strategy produces.
def p10k-unique-prefix [parent: string, name: string]: nothing -> string {
  let siblings = (try { ls -a $parent | where {|entry| $entry.type == "dir"} | get name | each {|path| $path | path basename } } catch { [] })
  let others = ($siblings | where {|sibling| $sibling != $name })
  let limit = ($name | str length --grapheme-clusters)
  mut size = 1
  mut prefix = ($name | str substring 0..0)
  while ($size < $limit) and ($others | any {|sibling| $sibling | str starts-with $prefix }) {
    $size = $size + 1
    $prefix = ($name | str substring 0..($size - 1))
  }
  $prefix
}

def p10k-path []: nothing -> string {
  let home = $env.HOME
  let pwd = $env.PWD
  let under_home = ($pwd == $home) or ($pwd | str starts-with ($home + "/"))
  let root = ($pwd == "/")
  let comps = if $pwd == $home {
    []
  } else if $under_home {
    ($pwd | str substring (($home | str length --grapheme-clusters) + 1).. | path split)
  } else if $root {
    []
  } else {
    ($pwd | path split | skip 1)
  }

  let head = (if $under_home { "~" } else { "/" })
  let plain = ($head + (if ($comps | is-empty) { "" } else { "/" + ($comps | str join "/") }))
  let overflow = (($plain | str length --grapheme-clusters) > 80)

  mut budget = ($plain | str length --grapheme-clusters)
  mut parent = (if $under_home { $home } else { "" })
  mut shown = []

  for item in ($comps | enumerate) {
    let comp = ($item.item)
    let full = (if $parent == "" { "/" + $comp } else { $parent | path join $comp })
    let is_first = (($item.index == 0) and (not $under_home))
    let is_last = ($item.index == (($comps | length) - 1))
    let anchor = ($is_first or $is_last or (($full | path join ".git") | path exists))
    let can_shorten = ($overflow) and (not $anchor) and ($budget > 80)
    let text = (if $can_shorten { p10k-unique-prefix $parent $comp } else { $comp })
    $budget = $budget - (($comp | str length --grapheme-clusters) - ($text | str length --grapheme-clusters))
    $shown = ($shown | append {text: $text, anchor: $anchor, shortened: (($can_shorten) and ($text != $comp))})
    $parent = $full
  }

  mut out = (if $root {
    p10k-color "dir" "/"
  } else if $under_home {
    p10k-color-bold "anchor" "~"
  } else {
    ""
  })
  for item in $shown {
    let segment = if $item.anchor {
      p10k-color-bold "anchor" $item.text
    } else if $item.shortened {
      p10k-color "shortened" $item.text
    } else {
      p10k-color "dir" $item.text
    }
    $out = $out + (p10k-color "dir" "/") + $segment
  }
  $out
}

def p10k-dirty-marker [name: string, icon: string, count: int]: nothing -> string {
  if $count > 0 {
    " " + (p10k-color $name ($icon + ($count | into string)))
  } else {
    ""
  }
}

# Git status comes from one `git status --porcelain=v1 --branch` call. The
# formatter follows the my_git_formatter function in ~/.p10k.zsh: green branch,
# yellow counts for staged and unstaged files, blue untracked, red conflicts.
def p10k-vcs []: nothing -> string {
  let res = (^git status --porcelain=v1 --branch | complete)
  if $res.exit_code != 0 {
    return ""
  }

  let lines = ($res.stdout | lines)
  if ($lines | is-empty) {
    return ""
  }

  let header = ($lines | first)
  if not ($header | str starts-with "## ") {
    return ""
  }

  let head = ($header | str substring 3..)
  let local = ($head | split row "..." | first | split row " " | first)
  let detached = ($local == "HEAD")
  let branch = if $detached {
    "@" + (^git rev-parse --short=8 HEAD | str trim)
  } else {
    $local
  }

  let shown = if (($branch | str length --grapheme-clusters) > 32) {
    ($branch | str substring 0..11) + "…" + ($branch | str substring (($branch | str length --grapheme-clusters) - 12)..)
  } else {
    $branch
  }

  let ahead_hit = ($head | parse -r 'ahead (?P<n>\d+)')
  let behind_hit = ($head | parse -r 'behind (?P<n>\d+)')
  let ahead = (if ($ahead_hit | is-empty) { 0 } else { $ahead_hit.0.n | into int })
  let behind = (if ($behind_hit | is-empty) { 0 } else { $behind_hit.0.n | into int })

  let xy = ($lines | skip 1 | each {|line| $line | str substring 0..1 })
  let conflicted_xy = ($xy | where {|s| ($s | str contains "U") or ($s == "AA") or ($s == "DD") })
  let plain_xy = ($xy | where {|s| not (($s | str contains "U") or ($s == "AA") or ($s == "DD")) })
  let untracked = ($xy | where {|s| $s == "??"} | length)
  let conflicted = ($conflicted_xy | length)
  let staged = ($plain_xy | where {|s| ($s | str substring 0..0) in ["M" "A" "D" "R" "C"] } | length)
  let unstaged = ($plain_xy | where {|s| ($s | str substring 1..1) in ["M" "A" "D" "R" "C"] } | length)

  mut counts = ""
  if $behind > 0 {
    $counts = $counts + " " + (p10k-color "git" ("⇣" + ($behind | into string)))
  }
  if $ahead > 0 {
    $counts = $counts + (if $behind == 0 { " " } else { "" }) + (p10k-color "git" ("⇡" + ($ahead | into string)))
  }
  $counts = $counts + (p10k-dirty-marker "conflict" "~" $conflicted)
  $counts = $counts + (p10k-dirty-marker "dirty" "+" $staged)
  $counts = $counts + (p10k-dirty-marker "dirty" "!" $unstaged)
  $counts = $counts + (p10k-dirty-marker "untracked" "?" $untracked)

  (p10k-color "git" ("\u{F113} \u{F126} " + $shown)) + $counts
}

# Right prompt, in p10k order: direnv, Nix shell, clock.
def p10k-right []: nothing -> string {
  mut parts = []
  if (($env.DIRENV_DIR? | default "") | is-not-empty) {
    $parts = ($parts | append (p10k-color "direnv" "▼"))
  }
  let nix_shell = ($env.IN_NIX_SHELL? | default "")
  if ($nix_shell == "pure") or ($nix_shell == "impure") {
    $parts = ($parts | append (p10k-color "nix" ("\u{F313} " + $nix_shell)))
  }
  let clock = (date now | format date "%H:%M:%S")
  $parts = ($parts | append (p10k-color "clock" ("\u{F017} " + $clock)))
  $parts | str join " "
}

def p10k-left []: nothing -> string {
  let vcs = (p10k-vcs)
  let vcs_part = (if ($vcs | is-empty) { "" } else { " " + $vcs })
  (p10k-color "frame" "╭─") + " " + (p10k-color "text" (p10k-os-icon)) + " " + (p10k-color "dir" "\u{F07C}") + " " + (p10k-path) + $vcs_part
}

def p10k-indicator []: nothing -> string {
  let name = if (($env.LAST_EXIT_CODE? | default 0) == 0) { "ok" } else { "fail" }
  (p10k-color $name "❯") + " "
}

# Draw the right prompt into the first line with spaces. Nushell puts
# PROMPT_COMMAND_RIGHT on the cursor line, while p10k puts it on the directory
# line, so the alignment is done by hand and the native right prompt is cleared
# below.
$env.PROMPT_COMMAND = {||
  let left = (p10k-left)
  let right = (p10k-right)
  let cols = (term size | get columns)
  let left_len = ($left | ansi strip | str length --grapheme-clusters)
  let right_len = ($right | ansi strip | str length --grapheme-clusters)
  let gap = ($cols - $left_len - $right_len - 1)
  let padded = (if ($right_len > 0) and ($gap > 0) { ("" | fill --width $gap) + $right } else { "" })
  "\n" + $left + $padded + "\n" + (p10k-color "frame" "╰─")
}
$env.PROMPT_COMMAND_RIGHT = {|| "" }
$env.PROMPT_MULTILINE_INDICATOR = ""
$env.PROMPT_INDICATOR = {|| p10k-indicator }

# p10k runs with POWERLEVEL9K_TRANSIENT_PROMPT=always, so accepted commands
# collapse to a prompt character colored by the exit status.
$env.TRANSIENT_PROMPT_COMMAND = ""
$env.TRANSIENT_PROMPT_INDICATOR = {|| p10k-indicator }
$env.TRANSIENT_PROMPT_INDICATOR_VI_INSERT = {|| p10k-indicator }
$env.TRANSIENT_PROMPT_INDICATOR_VI_NORMAL = {|| p10k-indicator }
$env.TRANSIENT_PROMPT_MULTILINE_INDICATOR = ""
$env.TRANSIENT_PROMPT_COMMAND_RIGHT = ""
