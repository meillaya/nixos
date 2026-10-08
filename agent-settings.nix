# Rules for agents working in this repo: repo facts, code style, tests, commit
# messages, prose, and how to write well.
#
# This file is data, not a flake output. Nothing imports it and no host
# evaluates it, so it never reaches `nix flake check`.
#
# `tools/check-prose.py` enforces the mechanical half of the prose rules and is
# exempt from them because it names every banned word. This file is exempt for
# the same reason: it has to spell the rules out. `tests/prose.sh` runs the
# checker over everything else.
let
  repoInstructions = ''
    ## This repo

    A personal Nix flake: NixOS workstations, one nix-darwin host, and a
    standalone Linux Home Manager host. Den owns the entity and aspect tree;
    flake-parts owns the outputs. Read `AGENTS.md` and the `AGENTS.md` under a
    directory before editing it.

    - Hosts: `remembrance` and `antagony` (NixOS), `entropy` (macOS),
      `standalone-linux` (Home Manager on CachyOS).
    - Behavior belongs in an aspect under `modules/aspects/`. Entities carry
      identity and data only.
    - Never call `nixosSystem`, `darwinSystem`, or `homeManagerConfiguration`
      in `flake.nix`. Den creates those.
    - Never add `specialArgs` or `extraSpecialArgs` in `flake.nix`,
      `modules/flake`, `modules/entities`, or `modules/aspects`.
    - Never hardcode `mei`, `/home/mei`, or `/Users/mei` in an active module.
      Read `host.machine.identity`.
    - `zix` owns package-list edits. Never hand-edit `zix/managed/*` or the
      inside of a `# BEGIN zix` block; run `zix add` / `zix rm`.

    ## Environment

    This is NixOS, not an FHS distribution.

    - Do not install tools imperatively. No `pip install`, `npm -g`,
      `cargo install`, or `apt`. Run a one-off tool with
      `nix run nixpkgs#<pkg> -- ...` or `nix shell nixpkgs#<pkg> -c <cmd>`.
      To keep a tool, add it to the Nix config instead.
    - Downloaded ELF binaries usually fail on the dynamic linker. Prefer a
      nixpkgs build; if a foreign binary is unavoidable, use `patchelf` or
      `nix run nixpkgs#steam-run -- ./binary`.
    - Python in this repo is stdlib only, with a PEP 723 header. Invoke it as
      `python3 -B` with `PYTHONPATH=<repo root>`, and import through
      `scripts.hardware.*` and `scripts.support.*`.

    ## Before you call it done

    - `nix run .#build` for a dry-run toplevel build.
    - `bash tests/dendritic-architecture.sh`, `dendritic-boundaries.sh`,
      `dendritic-apps.sh`, `dendritic-shells.sh`, `package-policy.sh`, `zix.sh`.
    - `nix flake check --all-systems --no-build`, or the narrower check you
      touched, such as `nix build .#checks.x86_64-linux.<name>`.
    - `bash tests/prose.sh` after any prose or comment change.
    - Run the `tests/bootstrap-password-*` scripts only for an install or a
      password change; they bind-mount `/var/lib` and `/etc/shadow`.

    ## Secrets

    `secrets/*` is git-ignored except for the three tracked files. Never commit
    a private key. Use `bin/nix-config-host-key-enroll` rather than editing
    `secrets/remembrance-keys.yaml`, and never hand-edit
    `config/hosts/intake/*.json`.
  '';

  # The person's own rules, repunctuated to drop the em dashes this repo bans.
  codeStyle = ''
    ## Code style

    - Always use braces after `if`, even for a single-line body. The only exception
      is if you are working in a codebase that has a strong, well-documented style
      guide that explicitly prefers or allows omitting braces for single-line bodies.
    - No magic numbers or strings. Hoist them into named constants, or better,
      an enum.
    - Prefer enums over booleans for function parameters, so a call site reads as
      what it means instead of `true`/`false`.
    - Use early returns and `continue` aggressively to keep indentation shallow.
    - Let the reader breathe: separate logical blocks with a blank line, and put
      a short, to-the-point comment above each block explaining what it does.
    - Only delete a comment when it is obsolete. When you change code, re-read
      the comment above it and make sure it is still correct.
    - Avoid bare pronouns in comments ("it", "this", "those"). Name the thing:
      not "It serves those file migration methods" but "This method serves x, y,
      and any method that has set up a migration source and sink".

    ## Tests

    - When working on a patch, write the test first. Watch it fail. Then write
      the code. Then watch it pass.
    - Open every test class and test function with a short comment saying what
      it tests and how it tests it.

    ## Commit messages

    Follow these seven rules whenever you write or proof-read one:

    1. Separate the subject line from the body with a single blank line.
    2. Limit the subject line to 50 characters (72 is the hard limit).
    3. Capitalize the first letter of the subject line.
    4. Do not end the subject line with a period.
    5. Use the imperative mood in the subject line ("Fix bug", "Add feature",
       not "Fixed" or "Adds"). It must complete the sentence "If applied, this
       commit will ___".
    6. Wrap the body at 72 characters, manually, to avoid git formatting issues.
    7. Use the body to explain what and why, not how. The code explains the how;
       the message explains the context and the reasoning.

    ## Tone

    - Talk to me like an engineer. Be direct and to the point, not verbose.
    - No superlatives and no praise. Give me the cold hard truth.
  '';

  # Anti-slop rules for prose. The banned vocabulary and phrase lists live in
  # tools/check-prose.py, which enforces them; the constructions below are the
  # part a checker cannot decide.
  writingStyle = ''
    ## Writing style: no LLM tells

    Applies to every word of prose: chat replies, commit messages, PR
    descriptions, docs, design notes, and code comments. The goal is writing
    that reads like a competent engineer typed it. When a rule here collides
    with being clear, be clear.

    `tools/check-prose.py` is the mechanical gate. It rejects the banned
    vocabulary, the banned phrases, and the em dash. Run `bash tests/prose.sh`
    before you call a prose change done.

    ### Banned constructions

    - Paired negation: a clause that denies one thing and then asserts its
      opposite twin. Say the thing that is true and stop.
    - "No X, no Y" chains. Rewrite them as a sentence.
    - Didactic hedging that announces a sentence's importance before it
      arrives. If it matters, state it; if it does not, delete it.
    - Puffery and significance inflation: claims that something matters, marks a
      moment, or plays a role. Name the effect and the number instead.
    - Participle tails: a sentence that ends by explaining what a fact
      "highlights", "reflects", "shows", or "underscores". That clause is
      commentary you invented.
    - Vague attribution ("experts argue", "studies show"). Cite a specific
      source or drop the claim.
    - Challenges-and-outlook boilerplate, and stage-managed reveals.
    - Performative honesty, therapy voice, and superlative narrowing.
    - Obituary headlines, dev-blog boilerplate, and rhetorical question stacks.
    - Sentence-skeleton repetition: consecutive sentences on one frame, or three
      sentences in a row opening on the same word.
    - Padding a list to three items for rhythm. Two is fine. So is four.

    ### Formatting

    - No emoji unless the person used one first.
    - No bold for emphasis scattered through a paragraph. Bold marks a genuine
      label, rarely.
    - Sentence case for headings.
    - Straight quotes and apostrophes.
    - No em dash. Use a comma, a colon, or a full stop.
    - Do not turn prose into a bulleted list of noun phrases. Prose is the
      default; a list is for things that are genuinely a list.
    - No closing paragraph that restates what you just said, and no opening
      paragraph that restates the question.

    ### What to do instead

    Short declarative sentences. Concrete nouns and specific numbers. Name what
    happened and what it means for the reader. If you are uncertain, say what
    you do not know instead of smoothing it over with confident filler.
  '';

  # The positive half: what good technical prose does. Drawn from the sources at
  # the end of this string, all of them fetched and checked on 2026-10-07.
  writingCraft = ''
    ## How to write well

    The rules above remove tells. These rules build the thing that is supposed
    to be there instead.

    ### Put actors in subjects and actions in verbs

    - Make the subject the actor. A sentence is easy to read when the thing
      doing the work sits at the front.
    - Make the verb the action. When the action hides inside a noun, the reader
      has to reconstruct it ("perform a validation of the file" against
      "validate the file").
    - Reach the main verb early, and keep introductory phrases short. Words
      between subject and verb sit in memory until the sentence resolves.
    - Prefer the active voice. The passive hides the actor and usually adds a
      word.
    - State things positively. A doubled negative makes the reader hold two
      states in mind to reach one fact.
    - Prefer the short familiar word to the long one, and the concrete word to
      the abstraction. Abstractions hide who did what, so there is nothing left
      to check.

    ### Order information for the reader

    - Open with what the reader already knows and end with what is new. The end
      of a sentence is where new information lands hardest.
    - Put the word you want remembered at the end of the sentence. Position
      carries emphasis that adjectives cannot.
    - Keep related words together, especially a modifier and what it modifies.
      Distance between them invites the wrong reading.
    - Express parallel ideas in parallel form. Mismatched shapes make the reader
      re-parse the list.
    - Give each paragraph one idea, and put the point in the first sentence.
      Readers scan, and a point they find late is a point they miss.
    - Keep paragraphs under about six sentences, and never summarize a section
      at the end of that section.

    ### Cut what carries no meaning

    - Omit needless words. Every word removed gives the survivors more weight.
    - Cut prepositional padding and redundant modifiers.
    - Use one word where a phrase will do.
    - Delete the concession paragraph that names obstacles and then predicts a
      brighter future. It turns a finding into a brochure.

    ### Model the reader you do not have

    - Assume the reader lacks your context. Writers who know too much leave out
      the steps that make the text usable.
    - Spell out the intermediate step. The step that feels obvious to you is the
      one the reader is missing.
    - Give one concrete example before any generalization. An example lets the
      reader check the rule against something real.
    - Define jargon at first use, or drop it.
    - Address the reader as "you", write in the present tense, and choose one
      term for one thing and keep it. Synonyms make the reader wonder whether
      two words mean two things.
    - Write as if pointing at something in the world rather than at your own
      process.

    ### Pick the form before writing

    - Choose the document type first, and keep the types in separate documents.
      Tutorials teach, how-tos guide, reference states, explanation discusses.
      Merged text does none of them well.

    ### README

    - Answer three questions on the first screen: what this is, who it is for,
      and the first command to run.
    - Describe in one line what the project does, in specific terms.
    - Show the shortest working example, copied from a session that actually
      ran. A snippet that ran beats a feature list.
    - Link deeper documents instead of inlining them. A README that explains
      everything stops being a front door.

    ### Reference documentation

    - Describe the machinery and leave out narrative and advice.
    - Document every parameter, default, and error. The gaps are what readers
      came for.
    - Use one entry shape per item, with fields in the same order every time, so
      the reader can scan down a column.

    ### How-to guide and runbook

    - Name the goal in the title, as an action and a target.
    - List the prerequisites first. A step that fails halfway for an unstated
      reason wastes the reader's afternoon.
    - Number the steps, put one action in each, and write them as imperatives.
      Two actions in one step hide the failure point.
    - State the expected end state and one command that verifies it.
    - Say what to do when a step fails and how to undo it. Recovery is the part
      that gets used under pressure.

    ### Design doc and RFC

    - Open with context and scope. Readers cannot judge a design before they
      know the ground it stands on.
    - List goals and non-goals separately. Non-goals stop the review from
      arguing about a different project.
    - Give the chosen design before the alternatives, and record why you
      rejected the others. The rejection reasons are what future readers come
      back for.
    - Use MUST, SHOULD, and MAY only in the sense RFC 2119 gives them.

    ### Blog post

    - Lead with the finding or the question that drove the work, and show the
      failure before the tidy lesson. The first paragraph decides whether the
      rest gets read, and the raw case is the evidence.

    ### Paper and technical report

    - Give each section one claim and put the evidence beside it. Split apart,
      they force the reader to hold the claim while searching for support.
    - Describe the method before the results. Results without a method cannot be
      judged or repeated.
    - Quantify where you can, cite where you borrow, and report what you did not
      test. Those are the three things a reader can check.

    ### Commit message

    - Write the subject in the imperative mood, as a command to the codebase.
      The log then reads as a list of applied changes.
    - Capitalize the subject, keep it near 50 characters, and leave off the
      final period.
    - Explain why in the body, not how. The diff already shows how.
    - Keep one logical change per commit, and mark a breaking change with the
      footer the project uses.

    ### Code comment

    - Never restate the code in prose. A comment that repeats the line goes
      stale the moment the line changes.
    - Explain why the code is shaped this way. The reader can see what it does;
      the reason is the missing part.
    - Comment the unidiomatic step so nobody "fixes" it. Code that looks wrong
      without its reason gets rewritten.
    - Link the source when you copy code, and record a known gap in the same
      change that creates it.

    ### Worked rewrites

    - Significance clause. Sloppy: "The retry queue is an important part of the
      pipeline, showing how much the team cares about reliability." Rewrite:
      "The retry queue holds a failed upload for 24 hours, so a flaky network
      does not lose data."
    - Paired negation. Sloppy: "Edge caching is not a nice extra we added for
      speed. It is the difference between a fast site and a slow one." Rewrite:
      "Edge caching cut median page load from 2.1 s to 0.4 s."
    - Three-adjective chain. Sloppy: "The service is fast, reliable, and easy to
      extend." Rewrite: "The service answers in 40 ms and keeps serving when one
      database node drops."
    - Action in the verb. Sloppy: "Configuration validation is performed by the
      loader before startup occurs." Rewrite: "The loader validates the
      configuration before startup."
    - Old information before new. Sloppy: "Three retries with a one-second pause
      in between is the policy this client follows before it finally gives up."
      Rewrite: "The client retries three times, one second apart, and then gives
      up."
    - Missing step. Sloppy: "Run the intake step, reconcile the digests, and the
      tree will evaluate." Rewrite: "Run `nix run .#intake` to write
      `config/hosts/intake/<host>.json`, then reconcile the digest against the
      record. The flake will not evaluate until the two agree."
    - Padding. Sloppy: "In order to be able to make the decision about whether to
      retry, the client needs to have an understanding of the current state of
      the connection." Rewrite: "The client retries only when the connection is
      up."
    - Commit subject. Sloppy: "fixed the thing with the locks that kept breaking
      the build sometimes". Rewrite: "Lock intake digests before the flake
      evaluates".

    ### Sources

    - Wikipedia, Signs of AI writing:
      https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing
    - Simon Willison, LLM cliche highlighter:
      https://tools.simonwillison.net/llm-cliche-highlighter
    - Orwell, Politics and the English Language:
      https://www.orwellfoundation.com/the-orwell-foundation/orwell/essays-and-other-works/politics-and-the-english-language/
    - Strunk and White, The Elements of Style, principles of composition:
      https://www.bartleby.com/lit-hub/the-elements-of-style/iii-elementary-principles-of-composition
    - Williams, Style: Lessons in Clarity and Grace:
      https://en.wikipedia.org/wiki/Style:_Lessons_in_Clarity_and_Grace
    - Review of Williams, Style: Toward Clarity and Grace (archived):
      https://web.archive.org/web/20120206080557/http://econ161.berkeley.edu/econ_articles/reviews/williams.html
    - Pinker, The Sense of Style:
      https://en.wikipedia.org/wiki/The_Sense_of_Style
    - Pinker on the curse of knowledge:
      https://www.psychologicalscience.org/observer/the-curse-of-knowledge-pinker-describes-a-key-cause-of-bad-writing
    - Google developer documentation style guide: https://developers.google.com/style
    - Google, paragraph structure:
      https://developers.google.com/style/paragraph-structure
    - Microsoft Writing Style Guide:
      https://learn.microsoft.com/en-us/style-guide/welcome/
    - Microsoft, top 10 tips for style and voice:
      https://learn.microsoft.com/en-us/style-guide/top-10-tips-style-voice
    - Plain language guidelines, choose your words carefully:
      https://raw.githubusercontent.com/GSA/plainlanguage.gov/main/_pages/guidelines/words/index.md
    - Plain language guidelines, be concise:
      https://raw.githubusercontent.com/GSA/plainlanguage.gov/main/_pages/guidelines/concise/index.md
    - Diataxis: https://diataxis.fr
    - Diataxis, the map: https://diataxis.fr/map/
    - Make a README: https://www.makeareadme.com/
    - Chris Beams, How to Write a Git Commit Message: https://cbea.ms/git-commit/
    - Conventional Commits: https://www.conventionalcommits.org/en/v1.0.0/
    - Design docs at Google:
      https://www.industrialempathy.com/posts/design-docs-at-google/
    - RFC 2119, key words for requirement levels: https://www.ietf.org/rfc/rfc2119.txt
    - Stack Overflow, best practices for writing code comments:
      https://stackoverflow.blog/2021/12/23/best-practices-for-writing-code-comments/
  '';
in {
  inherit repoInstructions codeStyle writingStyle writingCraft;

  instructions = ''
    ${repoInstructions}

    ${codeStyle}

    ${writingStyle}

    ${writingCraft}
  '';
}
