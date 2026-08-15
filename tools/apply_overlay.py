#!/usr/bin/env python3
"""Apply this repository's mobile-editor overlay to a pinned Psych Engine tree.

The upstream Android port is intentionally kept as an immutable base.  This script
copies overlay files and performs a few small, anchor-checked integration patches.
If upstream code changes and an anchor stops matching, the build fails instead of
silently producing a half-patched APK.
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Patch anchor mismatch in {path}: expected 1 match, got {count}\nANCHOR:\n{old}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: apply_overlay.py <upstream-engine-dir>")

    engine = Path(sys.argv[1]).resolve()
    repo = Path(__file__).resolve().parents[1]
    overlay = repo / "overlay"
    if not (engine / "Project.xml").exists():
        raise SystemExit(f"Not a Psych Engine checkout: {engine}")

    # Copy additive/replacement files first.
    for src in overlay.rglob("*"):
        if src.is_dir():
            continue
        rel = src.relative_to(overlay)
        dst = engine / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        print(f"overlay: {rel}")

    # Mobile Week Editor is the Android default; desktop keeps the classic state.
    master = engine / "source/editors/MasterEditorMenu.hx"
    replace_once(
        master,
        "\t\t\t\tcase 'Week Editor':\n\t\t\t\t\tMusicBeatState.switchState(new WeekEditorState());",
        "\t\t\t\tcase 'Week Editor':\n\t\t\t\t\t#if android\n\t\t\t\t\tMusicBeatState.switchState(new mobile.MobileWeekEditorState());\n\t\t\t\t\t#else\n\t\t\t\t\tMusicBeatState.switchState(new WeekEditorState());\n\t\t\t\t\t#end",
    )

    # Add a mobile toolbar + visual event editor hook to the existing ChartingState.
    chart = engine / "source/editors/ChartingState.hx"
    replace_once(
        chart,
        "import ui.FlxVirtualPad;\n",
        "import ui.FlxVirtualPad;\n#if android\nimport editors.mobile.MobileChartBridge;\n#end\n",
    )
    replace_once(
        chart,
        "\tvar _pad:FlxVirtualPad;\n",
        "\tvar _pad:FlxVirtualPad;\n\t#if android\n\tvar mobileBridge:MobileChartBridge;\n\t#end\n",
    )
    replace_once(
        chart,
        "\t\tsuper.create();\n\t}\n",
        "\t\t#if android\n\t\tmobileBridge = new MobileChartBridge(this);\n\t\tadd(mobileBridge);\n\t\t#end\n\n\t\tsuper.create();\n\t}\n",
    )

    # Expose a deliberately small adapter API. These wrappers call the original
    # editor methods/data; gameplay/timing code remains untouched.
    insertion_anchor = "\n\toverride function update(elapsed:Float)\n\t{"
    text = chart.read_text(encoding="utf-8")
    if text.count(insertion_anchor) != 1:
        raise SystemExit("Could not locate ChartingState.update integration anchor")
    adapter = r'''

	#if android
	public function mobileGetSong():SwagSong return _song;
	public function mobileGetSelectedNote():Array<Dynamic> return curSelectedNote;
	public function mobileChangeSection(delta:Int):Void changeSection(curSection + delta);
	public function mobileUndo():Void {
		// 0.4.2 did not ship a generic command stack. MobileChartBridge snapshots
		// chart JSON before mutating operations and restores through this hook.
		if (mobileBridge != null) mobileBridge.restoreUndo();
	}
	public function mobileRedo():Void {
		if (mobileBridge != null) mobileBridge.restoreRedo();
	}
	public function mobileDeleteSelected():Void {
		if (curSelectedNote != null) deleteNote(curSelectedNote);
	}
	public function mobileSaveDirect():Void {
		if (mobileBridge != null) mobileBridge.saveDirect();
	}
	public function mobileOpenEventEditor():Void {
		if (mobileBridge != null) mobileBridge.openEventEditor();
	}
	public function mobileRefreshGrid():Void updateGrid();
	#end
'''
    chart.write_text(text.replace(insertion_anchor, adapter + insertion_anchor, 1), encoding="utf-8")

    print("Mobile editor integration patches applied successfully.")


if __name__ == "__main__":
    main()
