#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script=$(readlink -f "${BASH_SOURCE[0]}")

scan_root() (
  set -euo pipefail
  python3 - "$1" <<'PY'
import errno
import hashlib
import os
import stat
import subprocess
import sys
from dataclasses import dataclass


class ScanFailure(Exception):
    pass


@dataclass(frozen=True)
class Candidate:
    path: str
    parents: tuple[tuple[int, ...], ...]
    metadata: tuple[int, ...]
    digest: bytes


DIRECTORY_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
FILE_FLAGS = os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK
SCOPES = ("hosts", "modules", "bin", "docs", "flake.nix", "overlays")
HASH_PATTERN = (
    r"\$(1|2[abxy]?|5|6|7|y|gy|sm3|sm3_yescrypt|gost_yescrypt|scrypt|yescrypt|"
    r"sha(256|512)crypt|bcrypt|pbkdf2(-sha(256|512))?|argon2(id|i|d))\$"
    r"[./A-Za-z0-9]"
)
PRIVATE_KEY_PATTERN = (
    r"BEGIN ([A-Z0-9]+[[:space:]]+)*PRIVATE KEY|BEGIN PGP PRIVATE KEY BLOCK|"
    r"AGE-SECRET-KEY-1"
)
PASSWORD_PROGRAM = r'''
  while (/(?<![-A-Za-z0-9_\x27])"?(initialPassword|password|hashedPassword|initialHashedPassword)"?(?![-A-Za-z0-9_\x27])(?:(?:\s+)|(?:\#[^\n]*(?:\n|\z))|(?:\/\*.*?\*\/))*=/sg) {
    print "$ARGV:$1\n";
  }
'''


def metadata(st: os.stat_result) -> tuple[int, ...]:
    return (
        st.st_dev,
        st.st_ino,
        st.st_mode,
        st.st_nlink,
        st.st_uid,
        st.st_gid,
        st.st_size,
        st.st_mtime_ns,
        st.st_ctime_ns,
    )


def validate_path(path: str) -> list[str]:
    parts = path.split("/")
    if not path or path.startswith("/") or any(part in ("", ".", "..") for part in parts):
        raise ScanFailure(f"invalid repository path: {path!r}")
    return parts


def open_candidate(root_fd: int, path: str, allow_missing: bool = False):
    parts = validate_path(path)
    current_fd = os.dup(root_fd)
    parents = []
    try:
        for part in parts[:-1]:
            try:
                next_fd = os.open(part, DIRECTORY_FLAGS, dir_fd=current_fd)
            except FileNotFoundError:
                if allow_missing:
                    return None
                raise ScanFailure(f"candidate disappeared during scan: {path}")
            except OSError as exc:
                raise ScanFailure(f"unsafe parent component for candidate {path}: {exc}")
            os.close(current_fd)
            current_fd = next_fd
            parent_stat = os.fstat(current_fd)
            if not stat.S_ISDIR(parent_stat.st_mode):
                raise ScanFailure(f"non-directory parent component for candidate: {path}")
            parents.append(metadata(parent_stat))

        try:
            candidate_fd = os.open(parts[-1], FILE_FLAGS, dir_fd=current_fd)
        except FileNotFoundError:
            if allow_missing:
                return None
            raise ScanFailure(f"candidate disappeared during scan: {path}")
        except OSError as exc:
            if exc.errno in (errno.EACCES, errno.EPERM):
                raise ScanFailure(f"cannot read tracked production path: {path}")
            raise ScanFailure(f"unsafe candidate path {path}: {exc}")
    finally:
        os.close(current_fd)

    candidate_stat = os.fstat(candidate_fd)
    if not stat.S_ISREG(candidate_stat.st_mode):
        os.close(candidate_fd)
        raise ScanFailure(f"production candidate is not a regular file: {path}")
    return candidate_fd, tuple(parents)


def read_digest(candidate_fd: int, path: str):
    initial = metadata(os.fstat(candidate_fd))
    digest = hashlib.sha256()
    try:
        while True:
            chunk = os.read(candidate_fd, 1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    except OSError as exc:
        raise ScanFailure(f"cannot read tracked production path: {path}: {exc}")
    if metadata(os.fstat(candidate_fd)) != initial:
        raise ScanFailure(f"candidate changed while being read: {path}")
    return initial, digest.digest()


def run_command(argv: list[str], root_fd: int, pass_fd: int | None = None):
    inherited = (root_fd,) if pass_fd is None else (root_fd, pass_fd)
    try:
        return subprocess.run(
            argv,
            pass_fds=inherited,
            preexec_fn=lambda: os.fchdir(root_fd),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except OSError as exc:
        raise ScanFailure(f"command execution failed: {argv[0]}: {exc}")


def parse_git_manifest(output: bytes, description: str) -> tuple[str, ...]:
    if not output:
        return ()
    if not output.endswith(b"\0"):
        raise ScanFailure(f"git {description} enumeration returned a malformed manifest")

    encoded_paths = output[:-1].split(b"\0")
    if any(not path for path in encoded_paths):
        raise ScanFailure(f"git {description} enumeration returned a malformed manifest")

    paths = []
    seen = set()
    for encoded_path in encoded_paths:
        path = os.fsdecode(encoded_path)
        validate_path(path)
        if path in seen:
            raise ScanFailure(f"git {description} enumeration returned a duplicate path: {path}")
        seen.add(path)
        paths.append(path)
    return tuple(sorted(paths, key=os.fsencode))


def git_paths(root_fd: int, argv: list[str], description: str) -> tuple[str, ...]:
    result = run_command(argv, root_fd)
    if result.returncode != 0:
        raise ScanFailure(f"git {description} enumeration failed")
    return parse_git_manifest(result.stdout, description)


def enumerate_paths(root_fd: int) -> tuple[tuple[str, ...], tuple[str, ...]]:
    paths = git_paths(
        root_fd,
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", *SCOPES],
        "file",
    )
    candidates = []
    for path in paths:
        opened = open_candidate(root_fd, path, allow_missing=True)
        if opened is not None:
            candidate_fd, _ = opened
            os.close(candidate_fd)
            candidates.append(path)
    tracked_deletions = git_paths(
        root_fd,
        ["git", "ls-files", "-z", "--deleted", "--", *SCOPES],
        "tracked-deletion",
    )
    return tuple(candidates), tracked_deletions


def scan_command(argv: list[str], root_fd: int, candidate_fd: int, failure: str, path: str):
    result = run_command(argv, root_fd, candidate_fd)
    if result.returncode not in (0, 1):
        raise ScanFailure(f"{failure}: {path}")
    return result


def scan_candidate(root_fd: int, path: str) -> tuple[Candidate, list[str]]:
    opened = open_candidate(root_fd, path)
    assert opened is not None
    candidate_fd, parents = opened
    try:
        candidate_metadata, digest = read_digest(candidate_fd, path)
        descriptor_path = f"/dev/fd/{candidate_fd}"
        matches = []

        if path.endswith(".nix"):
            result = run_command(
                ["perl", "-0777", "-ne", PASSWORD_PROGRAM, descriptor_path],
                root_fd,
                candidate_fd,
            )
            if result.returncode != 0:
                raise ScanFailure(f"password-option scan failed: {path}")
            password_matches = os.fsdecode(result.stdout).replace(descriptor_path, path).rstrip("\n")
            if password_matches:
                matches.append(password_matches)

        result = scan_command(
            ["grep", "-InE", HASH_PATTERN, descriptor_path],
            root_fd,
            candidate_fd,
            "password-hash scan failed",
            path,
        )
        hash_matches = os.fsdecode(result.stdout).rstrip("\n")
        if hash_matches:
            matches.append(f"{path}:{hash_matches}")

        result = scan_command(
            ["grep", "-InE", PRIVATE_KEY_PATTERN, descriptor_path],
            root_fd,
            candidate_fd,
            "private-key scan failed",
            path,
        )
        key_matches = os.fsdecode(result.stdout).rstrip("\n")
        if key_matches:
            matches.append(f"{path}:{key_matches}")

        if metadata(os.fstat(candidate_fd)) != candidate_metadata:
            raise ScanFailure(f"candidate changed during content scan: {path}")
        return Candidate(path, parents, candidate_metadata, digest), matches
    finally:
        os.close(candidate_fd)


def barrier():
    ready = os.environ.get("BOOTSTRAP_SECRET_TEST_READY_FIFO")
    release = os.environ.get("BOOTSTRAP_SECRET_TEST_RELEASE_FIFO")
    if bool(ready) != bool(release):
        raise ScanFailure("incomplete bootstrap scanner test barrier")
    if not ready:
        return
    try:
        with open(ready, "wb", buffering=0) as ready_stream:
            ready_stream.write(b"1")
        with open(release, "rb", buffering=0) as release_stream:
            if release_stream.read(1) != b"1":
                raise ScanFailure("bootstrap scanner test barrier was not released")
    except OSError as exc:
        raise ScanFailure(f"bootstrap scanner test barrier failed: {exc}")


def verify_root(root_fd: int, root_path: str, expected: tuple[int, ...]):
    if metadata(os.fstat(root_fd)) != expected:
        raise ScanFailure("scan root metadata changed during scan")
    try:
        path_metadata = metadata(os.stat(root_path, follow_symlinks=False))
    except OSError as exc:
        raise ScanFailure(f"cannot revalidate scan root: {exc}")
    if path_metadata != expected:
        raise ScanFailure("scan root path identity changed during scan")


def verify_repository_root(root_fd: int, expected: tuple[int, ...]):
    result = run_command(["git", "rev-parse", "--show-toplevel"], root_fd)
    if result.returncode != 0:
        raise ScanFailure("cannot verify repository root")
    repository_root = os.fsdecode(result.stdout).rstrip("\n")
    try:
        repository_metadata = metadata(os.stat(repository_root, follow_symlinks=False))
    except OSError as exc:
        raise ScanFailure(f"cannot anchor repository root: {exc}")
    if repository_metadata != expected:
        raise ScanFailure("scan root is not the repository root")


def main() -> int:
    root_path = sys.argv[1]
    try:
        root_fd = os.open(root_path, DIRECTORY_FLAGS)
    except OSError as exc:
        raise ScanFailure(f"cannot anchor scan root: {exc}")
    try:
        root_metadata = metadata(os.fstat(root_fd))
        verify_root(root_fd, root_path, root_metadata)
        verify_repository_root(root_fd, root_metadata)
        initial_paths, initial_tracked_deletions = enumerate_paths(root_fd)

        capture = os.environ.get("BOOTSTRAP_SECRET_MANIFEST_CAPTURE")
        if capture:
            try:
                with open(capture, "wb") as manifest:
                    manifest.write(b"".join(os.fsencode(path) + b"\0" for path in initial_paths))
            except OSError as exc:
                raise ScanFailure(f"cannot capture production manifest: {exc}")

        candidates = []
        matches = []
        for path in initial_paths:
            candidate, candidate_matches = scan_candidate(root_fd, path)
            candidates.append(candidate)
            matches.extend(candidate_matches)

        barrier()
        verify_root(root_fd, root_path, root_metadata)
        verify_repository_root(root_fd, root_metadata)

        for candidate in candidates:
            opened = open_candidate(root_fd, candidate.path)
            assert opened is not None
            candidate_fd, parents = opened
            try:
                current_metadata, digest = read_digest(candidate_fd, candidate.path)
            finally:
                os.close(candidate_fd)
            if parents != candidate.parents:
                raise ScanFailure(f"candidate parent identity changed during scan: {candidate.path}")
            if current_metadata != candidate.metadata or digest != candidate.digest:
                raise ScanFailure(f"candidate changed during scan: {candidate.path}")

        final_paths, final_tracked_deletions = enumerate_paths(root_fd)
        if final_paths != initial_paths:
            raise ScanFailure("production candidate enumeration changed during scan")
        if final_tracked_deletions != initial_tracked_deletions:
            raise ScanFailure("production tracked-deletion set changed during scan")

        verify_root(root_fd, root_path, root_metadata)
        if matches:
            print("\n".join(matches))
            return 1
        print("production_plain_or_inline_password_options=0")
        print("production_modular_password_hashes=0")
        print("production_private_key_markers=0")
        return 0
    finally:
        os.close(root_fd)


try:
    sys.exit(main())
except ScanFailure as exc:
    print(exc, file=sys.stderr)
    sys.exit(2)
except Exception as exc:
    print(f"bootstrap secret scan failed closed: {exc}", file=sys.stderr)
    sys.exit(2)
PY
)

if [[ ${1:-} == --scan-only ]]; then
  scan_root "$2"
  exit
fi

printf '%s\n' 'production-scan-scope=hosts,modules,bin,docs,flake.nix,overlays'

manifest_capture=$(mktemp -t nix-bootstrap-manifest-capture.XXXXXX)
manifest_expected=$(mktemp -t nix-bootstrap-manifest-expected.XXXXXX)
BOOTSTRAP_SECRET_MANIFEST_CAPTURE="$manifest_capture" scan_root "$repo"
git -C "$repo" ls-files -z --cached --others --exclude-standard -- \
  hosts modules bin docs flake.nix overlays \
  | while IFS= read -r -d '' path; do
      if [[ -e $repo/$path || -L $repo/$path ]]; then
        printf '%s\0' "$path"
      fi
    done > "$manifest_expected"
cmp "$manifest_expected" "$manifest_capture"
rm -f "$manifest_capture" "$manifest_expected"
printf 'production-manifest-complete=PASS\n'

tmp=$(mktemp -d -t nix-bootstrap-secret-scan.XXXXXX)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q
git config user.email verifier@example.invalid
git config user.name verifier

run_detected_case() {
  local name=$1 path=$2 content=$3 tracked=${4:-yes} output rc
  git rm -qrf --ignore-unmatch .
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" > "$path"
  if [[ $tracked == yes ]]; then
    git add "$path"
  fi
  set +e
  output=$(bash "$script" --scan-only "$tmp" 2>&1)
  rc=$?
  set -e
  if [[ $rc -ne 1 ]]; then
    printf 'fixture %s was not detected\n' "$name" >&2
    exit 1
  fi
  [[ $output == *"$path:"* ]]
  if [[ $tracked != yes ]]; then
    rm -f "$path"
  fi
  printf '%s-detection=PASS\n' "$name"
}

run_detected_case plaintext modules/config.nix \
  'users.users.mei.password = "fixture-only";'
run_detected_case multiline-initial modules/config.nix \
  'users.users.mei."initialPassword" # legal separator
    = "fixture-only";'
run_detected_case sha512 docs/fixture.txt \
  "\$6\$fixture\$not-a-real-verifier"
run_detected_case bcrypt docs/fixture.txt \
  "\$2b\$12\$fixturefixturefixturefixturefixturefixturefixturefixture"
run_detected_case phc-scrypt docs/fixture.txt \
  "\$scrypt\$ln=16,r=8,p=1\$fixture\$not-a-real-verifier"
run_detected_case private-key docs/fixture.pem \
  '-----BEGIN ENCRYPTED PRIVATE KEY-----'
run_detected_case age-key docs/fixture.txt \
  'AGE-SECRET-KEY-1FIXTUREONLY'
run_detected_case untracked-private-key docs/untracked.pem \
  '-----BEGIN PRIVATE KEY-----' no

git rm -qrf --ignore-unmatch .
mkdir -p modules bin
cat > modules/config.nix <<'EOF'
users.users.mei.hashedPasswordFile = "/var/lib/nixos-bootstrap/mei-password.hash";
den.aspects.bootstrap-password = { };
EOF
cat > bin/helper.fish <<'EOF'
set pattern '^\$y\$[./A-Za-z0-9]+\$hash$'
EOF
git add modules/config.nix bin/helper.fish
bash "$script" --scan-only "$tmp" >/dev/null
printf 'external-file-and-regex-negative-control=PASS\n'

git -c commit.gpgsign=false commit -qm 'test fixture'
rm modules/config.nix
bash "$script" --scan-only "$tmp" >/dev/null
printf 'tracked-working-tree-deletion-excluded=PASS\n'
git restore modules/config.nix

chmod 000 modules/config.nix
set +e
output=$(bash "$script" --scan-only "$tmp" 2>&1)
rc=$?
set -e
chmod 600 modules/config.nix
[[ $rc -eq 2 ]]
[[ $output == *'cannot read tracked production path: modules/config.nix'* ]]
printf 'unreadable-file-fails-closed=PASS\n'

mkdir -p mock-bin
cat > mock-bin/perl <<'EOF'
#!/usr/bin/env sh
exit 1
EOF
chmod +x mock-bin/perl
set +e
output=$(PATH="$PWD/mock-bin:$PATH" bash "$script" --scan-only "$tmp" 2>&1)
rc=$?
set -e
[[ $rc -eq 2 ]]
[[ $output == *'password-option scan failed: modules/config.nix'* ]]
printf 'search-process-error-fails-closed=PASS\n'
rm -rf mock-bin

real_git=$(command -v git)
mkdir -p mock-bin
cat > mock-bin/git <<'EOF'
#!/usr/bin/env sh
if [ "$1" = ls-files ]; then
  exit 2
fi
exec "$REAL_GIT" "$@"
EOF
chmod +x mock-bin/git
set +e
output=$(REAL_GIT="$real_git" PATH="$PWD/mock-bin:$PATH" \
  bash "$script" --scan-only "$tmp" 2>&1)
rc=$?
set -e
[[ $rc -eq 2 ]]
[[ $output != *'production_plain_or_inline_password_options=0'* ]]
printf 'git-file-list-error-fails-closed=PASS\n'
rm -f mock-bin/git

cat > mock-bin/grep <<'EOF'
#!/usr/bin/env sh
exit 2
EOF
chmod +x mock-bin/grep
set +e
output=$(PATH="$PWD/mock-bin:$PATH" bash "$script" --scan-only "$tmp" 2>&1)
rc=$?
set -e
[[ $rc -eq 2 ]]
[[ $output == *'password-hash scan failed:'* ]]
printf 'hash-search-error-fails-closed=PASS\n'

assert_no_zero_markers() {
  local output=$1
  [[ $output != *'production_plain_or_inline_password_options=0'* ]]
  [[ $output != *'production_modular_password_hashes=0'* ]]
  [[ $output != *'production_private_key_markers=0'* ]]
}

run_signal_grep_case() {
  local name=$1 signal_on=$2 expected_output=$3 counter output rc
  counter="$tmp/grep-counter"
  printf '0\n' > "$counter"
  cat > mock-bin/grep <<'EOF'
#!/usr/bin/env sh
count=$(cat "$MOCK_GREP_COUNTER")
count=$((count + 1))
printf '%s\n' "$count" > "$MOCK_GREP_COUNTER"
if [ "$count" -eq "$MOCK_GREP_SIGNAL_ON" ]; then
  kill -TERM "$$"
fi
exit 1
EOF
  chmod +x mock-bin/grep
  set +e
  output=$(MOCK_GREP_COUNTER="$counter" MOCK_GREP_SIGNAL_ON="$signal_on" \
    PATH="$PWD/mock-bin:$PATH" bash "$script" --scan-only "$tmp" 2>&1)
  rc=$?
  set -e
  [[ $rc -eq 2 ]]
  [[ $output == *"$expected_output"* ]]
  assert_no_zero_markers "$output"
  printf '%s=PASS\n' "$name"
}

run_signal_grep_case hash-search-signal-fails-closed 1 'password-hash scan failed:'
run_signal_grep_case private-key-search-signal-fails-closed 2 'private-key scan failed:'

counter="$tmp/grep-counter"
printf '0\n' > "$counter"
cat > mock-bin/grep <<'EOF'
#!/usr/bin/env sh
count=$(cat "$MOCK_GREP_COUNTER")
count=$((count + 1))
printf '%s\n' "$count" > "$MOCK_GREP_COUNTER"
if [ "$count" -eq 1 ]; then
  exit 1
fi
exit 2
EOF
chmod +x mock-bin/grep
set +e
output=$(MOCK_GREP_COUNTER="$counter" PATH="$PWD/mock-bin:$PATH" \
  bash "$script" --scan-only "$tmp" 2>&1)
rc=$?
set -e
[[ $rc -eq 2 ]]
[[ $output == *'private-key scan failed:'* ]]
printf 'private-key-search-error-fails-closed=PASS\n'
rm -rf mock-bin

run_revalidation_case() {
  local name=$1 mutation=$2 expected_rc=$3 expected_output=${4:-}
  local barrier_dir ready_fifo release_fifo output_file scan_pid output rc
  barrier_dir=$(mktemp -d "$tmp/revalidation.XXXXXX")
  ready_fifo=$barrier_dir/ready
  release_fifo=$barrier_dir/release
  output_file=$barrier_dir/output
  mkfifo "$ready_fifo" "$release_fifo"

  case $mutation in
    deleted-none|deleted-index-removal)
      rm modules/config.nix
      ;;
  esac

  BOOTSTRAP_SECRET_TEST_READY_FIFO="$ready_fifo" \
    BOOTSTRAP_SECRET_TEST_RELEASE_FIFO="$release_fifo" \
    bash "$script" --scan-only "$tmp" >"$output_file" 2>&1 &
  scan_pid=$!
  IFS= read -r -N 1 < "$ready_fifo"

  case $mutation in
    none|deleted-none)
      ;;
    deleted-index-removal)
      git rm -q --cached -- modules/config.nix
      ;;
    same-path)
      printf '%s\n' '# late same-path mutation' >> modules/config.nix
      ;;
    parent-symlink)
      mv modules modules-original
      mkdir modules-replacement
      ln -s modules-replacement modules
      ;;
    *)
      printf 'unknown revalidation mutation: %s\n' "$mutation" >&2
      exit 1
      ;;
  esac

  printf '1' > "$release_fifo"
  set +e
  wait "$scan_pid"
  rc=$?
  set -e
  output=$(<"$output_file")

  case $mutation in
    same-path)
      git restore modules/config.nix
      ;;
    deleted-none|deleted-index-removal)
      git restore --source=HEAD --staged --worktree -- modules/config.nix
      ;;
    parent-symlink)
      rm modules
      rmdir modules-replacement
      mv modules-original modules
      ;;
  esac

  if [[ $rc -ne $expected_rc ]]; then
    printf 'revalidation case %s returned %s, expected %s\n%s\n' \
      "$name" "$rc" "$expected_rc" "$output" >&2
    exit 1
  fi
  if [[ -n $expected_output && $output != *"$expected_output"* ]]; then
    printf 'revalidation case %s lacked expected output: %s\n%s\n' \
      "$name" "$expected_output" "$output" >&2
    exit 1
  fi
  rm -f "$ready_fifo" "$release_fifo" "$output_file"
  rmdir "$barrier_dir"
  printf '%s=PASS\n' "$name"
}

run_revalidation_case late-same-path-mutation-fails-closed same-path 2 \
  'candidate changed during scan: modules/config.nix'
run_revalidation_case parent-directory-symlink-race-fails-closed parent-symlink 2 \
  'scan root metadata changed during scan'
run_revalidation_case tracked-deletion-index-race-fails-closed deleted-index-removal 2 \
  'production tracked-deletion set changed during scan'
run_revalidation_case unchanged-tracked-deletion-control deleted-none 0 \
  'production_private_key_markers=0'
run_revalidation_case unchanged-revalidation-control none 0 \
  'production_private_key_markers=0'

printf 'cleanup=%s\n' "$tmp"
