#!/usr/bin/env python3
"""Build-manifest support for the ImcFlow VCS RTL runner.

The manifest is deliberately computed from the effective Make variables and
the contents of every compile input.  A matching fingerprint therefore means
that the existing ``simv`` was built from the same configuration and sources;
file mtimes are not used.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from typing import Dict, List, Mapping, Optional, Sequence


SCHEMA_VERSION = 1
STALE_EXIT_CODE = 10
SOURCE_SUFFIXES = {".c", ".cc", ".cpp", ".h", ".hpp", ".inc", ".sv", ".svh", ".v", ".vh"}
REQUIRED_BUILD_ENV = (
    "RTL_BUILD_BUGFIX_MODE",
    "RTL_BUILD_DEFINES",
    "RTL_BUILD_SIMUL_EXEC",
    "RTL_BUILD_SIMUL_OPTS",
    "RTL_BUILD_DPI_FLAGS",
    "RTL_BUILD_INCLUDE_DIRS",
    "RTL_BUILD_VCS_FLAGS",
    "RTL_BUILD_FILELISTS",
)
PATH_ENV_NAMES = ("IMCFLOW_DIR", "SHARED_IMCFLOW_DIR", "SHARED_GPIO_MODEL_DIR")
_ENV_PATTERN = re.compile(r"\$(?:\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*))")


class ManifestError(RuntimeError):
    """The requested build configuration cannot be represented safely."""


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _canonical_digest(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def _expand_env(text: str, env: Mapping[str, str], context: str) -> str:
    missing: List[str] = []

    def replace(match: re.Match[str]) -> str:
        name = match.group(1) or match.group(2)
        if name not in env:
            missing.append(name)
            return match.group(0)
        return env[name]

    expanded = _ENV_PATTERN.sub(replace, text)
    if missing:
        names = ", ".join(sorted(set(missing)))
        raise ManifestError(f"{context}: unset environment variable(s): {names}")
    return expanded


def _absolute_path(text: str, base_dir: Path, env: Mapping[str, str], context: str) -> Path:
    expanded = _expand_env(text, env, context)
    path = Path(expanded).expanduser()
    if not path.is_absolute():
        path = base_dir / path
    return path.resolve()


def _require_regular_file(path: Path, context: str) -> None:
    if not path.is_file():
        raise ManifestError(f"{context}: required file does not exist: {path}")


def _add_file(files: Dict[str, str], path: Path, context: str) -> None:
    _require_regular_file(path, context)
    files[str(path)] = _sha256_file(path)


def _add_include_tree(files: Dict[str, str], directory: Path) -> None:
    if not directory.is_dir():
        raise ManifestError(f"include directory does not exist: {directory}")
    for path in sorted(directory.rglob("*")):
        if path.is_file() and path.suffix.lower() in SOURCE_SUFFIXES:
            _add_file(files, path.resolve(), "include input")


def _filelist_inputs(
    filelist: Path,
    vcs_work_dir: Path,
    env: Mapping[str, str],
    files: Dict[str, str],
    visited: set,
) -> None:
    filelist = filelist.resolve()
    if filelist in visited:
        return
    visited.add(filelist)
    _add_file(files, filelist, "file list")

    with filelist.open("r", encoding="utf-8") as stream:
        for line_number, raw_line in enumerate(stream, start=1):
            line = raw_line.split("//", 1)[0].strip()
            if not line:
                continue
            context = f"{filelist}:{line_number}"
            try:
                tokens = shlex.split(line, comments=True, posix=True)
            except ValueError as exc:
                raise ManifestError(f"{context}: cannot parse file-list line: {exc}") from exc

            index = 0
            while index < len(tokens):
                token = tokens[index]
                if token in ("-v", "-f"):
                    if index + 1 >= len(tokens):
                        raise ManifestError(f"{context}: {token} requires a path")
                    input_path = _absolute_path(tokens[index + 1], vcs_work_dir, env, context)
                    if token == "-f":
                        _filelist_inputs(input_path, vcs_work_dir, env, files, visited)
                    else:
                        _add_file(files, input_path, context)
                    index += 2
                    continue
                if token.startswith("+incdir+"):
                    for include in token[len("+incdir+"):].split("+"):
                        if include:
                            _add_include_tree(
                                files, _absolute_path(include, vcs_work_dir, env, context)
                            )
                    index += 1
                    continue
                if not token.startswith(("-", "+")):
                    input_path = _absolute_path(token, vcs_work_dir, env, context)
                    _add_file(files, input_path, context)
                index += 1


def _tool_identity(executable: str, env: Mapping[str, str]) -> Dict[str, object]:
    expanded = _expand_env(executable, env, "RTL_BUILD_SIMUL_EXEC")
    resolved = shutil.which(expanded, path=env.get("PATH"))
    if resolved is None:
        candidate = Path(expanded).expanduser()
        if candidate.is_file():
            resolved = str(candidate.resolve())
    if resolved is None:
        raise ManifestError(f"simulator executable is not available: {expanded}")

    try:
        result = subprocess.run(
            [resolved, "-ID"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=30,
            check=False,
            env=dict(env),
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ManifestError(f"failed to identify simulator {resolved}: {exc}") from exc
    return {
        "requested": executable,
        "path": str(Path(resolved).resolve()),
        "id_command": ["-ID"],
        "id_returncode": result.returncode,
        "id_output": result.stdout.strip(),
    }


def compute_manifest(
    runner_dir: Path,
    env: Optional[Mapping[str, str]] = None,
    tool_identity: Optional[Mapping[str, object]] = None,
) -> Dict[str, object]:
    """Compute a manifest for the effective RTL compile configuration."""
    runner_dir = runner_dir.resolve()
    actual_env: Dict[str, str] = dict(os.environ if env is None else env)
    missing = [name for name in REQUIRED_BUILD_ENV if name not in actual_env]
    if missing:
        raise ManifestError("missing build configuration: " + ", ".join(missing))

    bugfix_mode = actual_env["RTL_BUILD_BUGFIX_MODE"].strip().lower()
    if bugfix_mode not in ("on", "off"):
        raise ManifestError(
            f"IMCFLOW_BUGFIX must be 'on' or 'off', got {actual_env['RTL_BUILD_BUGFIX_MODE']!r}"
        )

    vcs_work_dir = runner_dir / "build"
    files: Dict[str, str] = {}
    for infrastructure in (runner_dir / "Makefile", runner_dir / "build_manifest.py"):
        _add_file(files, infrastructure.resolve(), "build infrastructure")

    filelists: List[str] = []
    visited: set = set()
    for item in shlex.split(actual_env["RTL_BUILD_FILELISTS"]):
        path = _absolute_path(item, vcs_work_dir, actual_env, "RTL_BUILD_FILELISTS")
        filelists.append(str(path))
        _filelist_inputs(path, vcs_work_dir, actual_env, files, visited)

    include_dirs: List[str] = []
    for item in actual_env["RTL_BUILD_INCLUDE_DIRS"].split("+"):
        if not item:
            continue
        path = _absolute_path(item, vcs_work_dir, actual_env, "RTL_BUILD_INCLUDE_DIRS")
        include_dirs.append(str(path))
        _add_include_tree(files, path)

    path_env = {}
    for name in PATH_ENV_NAMES:
        if name not in actual_env:
            raise ManifestError(f"missing path environment variable: {name}")
        path_env[name] = str(Path(actual_env[name]).expanduser().resolve())

    payload: Dict[str, object] = {
        "schema_version": SCHEMA_VERSION,
        "compile": {
            "bugfix_mode": bugfix_mode,
            "defines": actual_env["RTL_BUILD_DEFINES"],
            "simulator": actual_env["RTL_BUILD_SIMUL_EXEC"],
            "simulator_options": actual_env["RTL_BUILD_SIMUL_OPTS"],
            "dpi_flags": actual_env["RTL_BUILD_DPI_FLAGS"],
            "vcs_flags": actual_env["RTL_BUILD_VCS_FLAGS"],
            "include_dirs": include_dirs,
            "filelists": filelists,
        },
        "path_environment": path_env,
        "tool": dict(tool_identity) if tool_identity is not None else _tool_identity(
            actual_env["RTL_BUILD_SIMUL_EXEC"], actual_env
        ),
        "inputs": [{"path": path, "sha256": digest} for path, digest in sorted(files.items())],
    }
    return {**payload, "fingerprint": _canonical_digest(payload)}


def _atomic_write_json(path: Path, value: Mapping[str, object]) -> None:
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_name: Optional[str] = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=str(path.parent), prefix=f".{path.name}.",
            suffix=".tmp", delete=False
        ) as stream:
            temporary_name = stream.name
            json.dump(value, stream, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_name, path)
    finally:
        if temporary_name and os.path.exists(temporary_name):
            os.unlink(temporary_name)


def _load_manifest(path: Path) -> Mapping[str, object]:
    with path.open("r", encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise ValueError("manifest root is not an object")
    return value


def _manifest_payload(manifest: Mapping[str, object]) -> Dict[str, object]:
    return {key: value for key, value in manifest.items() if key != "fingerprint"}


def _has_valid_fingerprint(manifest: Mapping[str, object]) -> bool:
    fingerprint = manifest.get("fingerprint")
    return isinstance(fingerprint, str) and fingerprint == _canonical_digest(
        _manifest_payload(manifest)
    )


def _input_map(manifest: Mapping[str, object]) -> Dict[str, str]:
    result = {}
    for item in manifest.get("inputs", []):
        if isinstance(item, dict) and "path" in item and "sha256" in item:
            result[str(item["path"])] = str(item["sha256"])
    return result


def describe_changes(old: Mapping[str, object], new: Mapping[str, object]) -> List[str]:
    reasons: List[str] = []
    for field in ("compile", "path_environment", "tool"):
        if old.get(field) != new.get(field):
            reasons.append(f"{field} configuration changed")
    old_inputs, new_inputs = _input_map(old), _input_map(new)
    added = sorted(set(new_inputs) - set(old_inputs))
    removed = sorted(set(old_inputs) - set(new_inputs))
    changed = sorted(path for path in set(old_inputs) & set(new_inputs)
                     if old_inputs[path] != new_inputs[path])
    for label, paths in (("added", added), ("removed", removed), ("changed", changed)):
        if paths:
            preview = ", ".join(paths[:3])
            suffix = f" (+{len(paths) - 3} more)" if len(paths) > 3 else ""
            reasons.append(f"input files {label}: {preview}{suffix}")
    if not reasons:
        reasons.append("fingerprint changed")
    return reasons


def check_manifest(runner_dir: Path, manifest_path: Path, binary_path: Path) -> int:
    if not binary_path.is_file():
        print(f"RTL rebuild required: simulator binary missing: {binary_path}")
        return STALE_EXIT_CODE
    if not manifest_path.is_file():
        print(f"RTL rebuild required: build manifest missing: {manifest_path}")
        return STALE_EXIT_CODE
    try:
        old = _load_manifest(manifest_path)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"RTL rebuild required: invalid build manifest: {exc}")
        return STALE_EXIT_CODE
    if old.get("schema_version") != SCHEMA_VERSION:
        print("RTL rebuild required: build manifest schema changed")
        return STALE_EXIT_CODE
    if not _has_valid_fingerprint(old):
        print("RTL rebuild required: build manifest fingerprint is invalid")
        return STALE_EXIT_CODE
    current = compute_manifest(runner_dir)
    if old.get("fingerprint") == current["fingerprint"]:
        print(f"RTL build is current ({current['fingerprint'][:12]})")
        return 0
    print("RTL rebuild required:")
    for reason in describe_changes(old, current):
        print(f"  - {reason}")
    return STALE_EXIT_CODE


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runner-dir", type=Path, default=Path(__file__).resolve().parent)
    subparsers = parser.add_subparsers(dest="command", required=True)
    prepare = subparsers.add_parser("prepare")
    prepare.add_argument("--output", type=Path, required=True)
    check = subparsers.add_parser("check")
    check.add_argument("--manifest", type=Path, required=True)
    check.add_argument("--binary", type=Path, required=True)
    finalize = subparsers.add_parser("finalize")
    finalize.add_argument("--pending", type=Path, required=True)
    finalize.add_argument("--output", type=Path, required=True)
    subparsers.add_parser("current")
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = _parser().parse_args(argv)
    runner_dir = args.runner_dir.resolve()
    try:
        if args.command == "check":
            return check_manifest(runner_dir, args.manifest, args.binary)
        current = compute_manifest(runner_dir)
        if args.command == "current":
            json.dump(current, sys.stdout, indent=2, sort_keys=True)
            sys.stdout.write("\n")
            return 0
        if args.command == "prepare":
            _atomic_write_json(args.output, current)
            print(f"Prepared RTL build manifest ({current['fingerprint'][:12]})")
            return 0
        if args.command == "finalize":
            pending = _load_manifest(args.pending)
            if not _has_valid_fingerprint(pending):
                print("Pending RTL build manifest has an invalid fingerprint")
                return 1
            if pending.get("fingerprint") != current["fingerprint"]:
                print("RTL inputs changed while VCS was compiling; refusing to stamp the build")
                for reason in describe_changes(pending, current):
                    print(f"  - {reason}")
                return 1
            args.output.resolve().parent.mkdir(parents=True, exist_ok=True)
            os.replace(args.pending.resolve(), args.output.resolve())
            print(f"Recorded RTL build manifest ({current['fingerprint'][:12]})")
            return 0
        raise AssertionError(f"unknown command: {args.command}")
    except (ManifestError, OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"build manifest error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
