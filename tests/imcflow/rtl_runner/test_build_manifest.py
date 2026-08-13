"""Unit tests for the RTL build-manifest invalidation rules."""

import importlib.util
import json
import os
from pathlib import Path
import subprocess

import pytest


MODULE_PATH = Path(__file__).with_name("build_manifest.py")
MAKEFILE_PATH = Path(__file__).with_name("Makefile")
SPEC = importlib.util.spec_from_file_location("rtl_build_manifest", MODULE_PATH)
manifest = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(manifest)


@pytest.fixture
def build_tree(tmp_path):
    runner = tmp_path / "runner"
    runner.mkdir()
    (runner / "build").mkdir()
    (runner / "Makefile").write_text(MAKEFILE_PATH.read_text(encoding="utf-8"), encoding="utf-8")
    (runner / "build_manifest.py").write_text(
        MODULE_PATH.read_text(encoding="utf-8"), encoding="utf-8"
    )

    imcflow = tmp_path / "imcflow"
    imcflow.mkdir()
    (imcflow / "rtl.sv").write_text("module rtl; endmodule\n", encoding="utf-8")
    include_dirs = []
    for name in ("top_include", "classes", "include"):
        directory = imcflow / name
        directory.mkdir()
        (directory / f"{name}.svh").write_text(f"// {name}\n", encoding="utf-8")
        include_dirs.append(directory)

    shared_imcflow = tmp_path / "shared_imcflow"
    shared_imcflow.mkdir()
    (shared_imcflow / "macro.v").write_text("module macro; endmodule\n", encoding="utf-8")
    shared_gpio = tmp_path / "shared_gpio"
    shared_gpio.mkdir()
    (shared_gpio / "gpio.v").write_text("module gpio; endmodule\n", encoding="utf-8")
    (runner / "tb.sv").write_text("module tb; endmodule\n", encoding="utf-8")

    (runner / "rtl.f").write_text("${IMCFLOW_DIR}/rtl.sv\n", encoding="utf-8")
    (runner / "tb.f").write_text("../tb.sv\n", encoding="utf-8")
    (runner / "tech.f").write_text(
        "-v ${SHARED_IMCFLOW_DIR}/macro.v\n-v ${SHARED_GPIO_MODEL_DIR}/gpio.v\n",
        encoding="utf-8",
    )

    fake_vcs = tmp_path / "fake-vcs"
    fake_vcs.write_text("#!/bin/sh\nprintf 'fake-vcs 1.0\\n'\n", encoding="utf-8")
    fake_vcs.chmod(0o755)

    env = {
        "PATH": os.environ["PATH"],
        "IMCFLOW_DIR": str(imcflow),
        "SHARED_IMCFLOW_DIR": str(shared_imcflow),
        "SHARED_GPIO_MODEL_DIR": str(shared_gpio),
        "RTL_BUILD_BUGFIX_MODE": "off",
        "RTL_BUILD_DEFINES": "BASE",
        "RTL_BUILD_SIMUL_EXEC": str(fake_vcs),
        "RTL_BUILD_SIMUL_OPTS": "",
        "RTL_BUILD_DPI_FLAGS": "-LDFLAGS",
        "RTL_BUILD_INCLUDE_DIRS": "+".join(str(path) for path in include_dirs),
        "RTL_BUILD_VCS_FLAGS": "-sverilog -full64",
        "RTL_BUILD_FILELISTS": "../tech.f ../rtl.f ../tb.f",
    }
    return runner, env


def test_manifest_is_stable_and_tracks_all_inputs(build_tree):
    runner, env = build_tree
    first = manifest.compute_manifest(runner, env)
    second = manifest.compute_manifest(runner, env)
    assert first == second
    assert first["compile"]["bugfix_mode"] == "off"
    assert len(first["inputs"]) == 12


@pytest.mark.parametrize(
    ("name", "value"),
    [
        ("RTL_BUILD_BUGFIX_MODE", "on"),
        ("RTL_BUILD_DEFINES", "BASE+BUGFIX_READ_FROM_GPR"),
        ("RTL_BUILD_SIMUL_OPTS", "-cm line"),
        ("RTL_BUILD_VCS_FLAGS", "-sverilog -full64 -xprop=tmerge"),
    ],
)
def test_compile_configuration_changes_fingerprint(build_tree, name, value):
    runner, env = build_tree
    original = manifest.compute_manifest(runner, env)
    changed_env = dict(env)
    changed_env[name] = value
    changed = manifest.compute_manifest(runner, changed_env)
    assert changed["fingerprint"] != original["fingerprint"]


def test_source_and_include_changes_invalidate_manifest(build_tree):
    runner, env = build_tree
    original = manifest.compute_manifest(runner, env)
    (Path(env["IMCFLOW_DIR"]) / "rtl.sv").write_text(
        "module rtl; wire changed; endmodule\n", encoding="utf-8"
    )
    source_changed = manifest.compute_manifest(runner, env)
    assert source_changed["fingerprint"] != original["fingerprint"]

    (Path(env["IMCFLOW_DIR"]) / "top_include" / "top_include.svh").write_text(
        "// changed include\n", encoding="utf-8"
    )
    include_changed = manifest.compute_manifest(runner, env)
    assert include_changed["fingerprint"] != source_changed["fingerprint"]


def test_check_handles_fresh_missing_and_corrupt_state(build_tree, monkeypatch):
    runner, env = build_tree
    for name, value in env.items():
        monkeypatch.setenv(name, value)
    binary = runner / "build" / "simv_imcflow_gem5"
    manifest_path = runner / "build" / "build_manifest.json"

    assert manifest.check_manifest(runner, manifest_path, binary) == manifest.STALE_EXIT_CODE
    binary.write_text("fake simv\n", encoding="utf-8")
    current = manifest.compute_manifest(runner)
    manifest._atomic_write_json(manifest_path, current)
    assert manifest.check_manifest(runner, manifest_path, binary) == 0

    manifest_path.write_text("{broken", encoding="utf-8")
    assert manifest.check_manifest(runner, manifest_path, binary) == manifest.STALE_EXIT_CODE


def test_make_ensure_compiled_reuses_matching_build(build_tree):
    runner, env = build_tree
    binary = runner / "build" / "simv_imcflow_gem5"
    manifest_path = runner / "build" / "build_manifest.json"
    binary.write_text("fake simv\n", encoding="utf-8")
    manifest._atomic_write_json(manifest_path, manifest.compute_manifest(runner, env))

    command = [
        "make",
        "ensure-compiled",
        "IMCFLOW_BUGFIX=off",
        "DEFINE=BASE",
        f"SIMUL_EXEC={env['RTL_BUILD_SIMUL_EXEC']}",
        "SIMUL_OPTS=",
        "DPI_FLAGS=-LDFLAGS",
        f"INCLUDE_DIR={env['RTL_BUILD_INCLUDE_DIRS']}",
        "VCS_FLAGS=-sverilog -full64",
        f"FILELISTS={env['RTL_BUILD_FILELISTS']}",
    ]
    process_env = os.environ.copy()
    process_env.update({name: env[name] for name in manifest.PATH_ENV_NAMES})
    result = subprocess.run(
        command, cwd=runner, env=process_env, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False
    )

    assert result.returncode == 0, result.stdout
    assert "RTL build is current" in result.stdout
    assert "Reusing manifest-matched RTL simulator" in result.stdout


def test_finalize_rejects_inputs_changed_during_compile(build_tree, monkeypatch):
    runner, env = build_tree
    for name, value in env.items():
        monkeypatch.setenv(name, value)
    pending = runner / ".pending.json"
    output = runner / "build" / "build_manifest.json"
    args = ["--runner-dir", str(runner)]

    assert manifest.main(args + ["prepare", "--output", str(pending)]) == 0
    (Path(env["IMCFLOW_DIR"]) / "rtl.sv").write_text("module changed; endmodule\n")
    assert manifest.main(
        args + ["finalize", "--pending", str(pending), "--output", str(output)]
    ) == 1
    assert pending.exists()
    assert not output.exists()


def test_finalize_atomically_promotes_pending_manifest(build_tree, monkeypatch):
    runner, env = build_tree
    for name, value in env.items():
        monkeypatch.setenv(name, value)
    pending = runner / ".pending.json"
    output = runner / "build" / "build_manifest.json"
    args = ["--runner-dir", str(runner)]

    assert manifest.main(args + ["prepare", "--output", str(pending)]) == 0
    assert manifest.main(
        args + ["finalize", "--pending", str(pending), "--output", str(output)]
    ) == 0
    assert not pending.exists()
    assert json.loads(output.read_text(encoding="utf-8"))["schema_version"] == 1


def test_invalid_bugfix_mode_is_rejected(build_tree):
    runner, env = build_tree
    invalid = dict(env)
    invalid["RTL_BUILD_BUGFIX_MODE"] = "maybe"
    with pytest.raises(manifest.ManifestError, match="must be 'on' or 'off'"):
        manifest.compute_manifest(runner, invalid)
