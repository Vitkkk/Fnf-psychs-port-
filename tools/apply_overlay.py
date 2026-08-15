#!/usr/bin/env python3
"""Apply the mobile-editor overlay to the pinned Kviks Psych Engine Android tree."""
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


def insert_once(path: Path, anchor: str, insertion: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(anchor)
    if count != 1:
        raise SystemExit(f"Insert anchor mismatch in {path}: expected 1 match, got {count}\nANCHOR:\n{anchor}")
    path.write_text(text.replace(anchor, insertion + anchor, 1), encoding="utf-8")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: apply_overlay.py <upstream-engine-dir>")
    engine = Path(sys.argv[1]).resolve()
    repo = Path(__file__).resolve().parents[1]
    if not (engine / "Project.xml").exists():
        raise SystemExit(f"Not a Psych Engine checkout: {engine}")

    for src in (repo / "overlay").rglob("*"):
        if src.is_dir():
            continue
        rel = src.relative_to(repo / "overlay")
        dst = engine / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        print(f"overlay: {rel}")

    master = engine / "source/editors/MasterEditorMenu.hx"
    replace_once(master,
        "\t\t\t\tcase 'Week Editor':\n\t\t\t\t\tMusicBeatState.switchState(new WeekEditorState());",
        "\t\t\t\tcase 'Week Editor':\n\t\t\t\t\t#if android\n\t\t\t\t\tMusicBeatState.switchState(new editors.mobile.MobileWeekEditorState());\n\t\t\t\t\t#else\n\t\t\t\t\tMusicBeatState.switchState(new WeekEditorState());\n\t\t\t\t\t#end")

    chart = engine / "source/editors/ChartingState.hx"
    replace_once(chart, "import ui.FlxVirtualPad;\n",
        "import ui.FlxVirtualPad;\n#if android\nimport editors.mobile.MobileChartBridge;\n#end\n")
    replace_once(chart, "\tvar _pad:FlxVirtualPad;\n",
        "\tvar _pad:FlxVirtualPad;\n\t#if android\n\tvar mobileBridge:MobileChartBridge;\n\tvar mobileCopiedNote:Array<Dynamic>;\n\tvar mobileCopiedSection:Array<Dynamic>;\n\t#end\n")
    replace_once(chart, "\t\tsuper.create();\n\t}\n",
        "\t\t#if android\n\t\tmobileBridge = new MobileChartBridge(this);\n\t\tadd(mobileBridge);\n\t\t#end\n\n\t\tsuper.create();\n\t}\n")

    insert_once(chart, "\tprivate function addNote():Void\n\t{",
        "\t#if android\n\tinline function mobileCheckpoint():Void if (mobileBridge != null) mobileBridge.checkpoint();\n\t#end\n\n")
    replace_once(chart,
        "\tprivate function addNote():Void\n\t{\n\t\tvar noteStrum",
        "\tprivate function addNote():Void\n\t{\n\t\t#if android\n\t\tmobileCheckpoint();\n\t\t#end\n\t\tvar noteStrum")
    replace_once(chart,
        "\tfunction deleteNote(note:Note):Void\n\t{\n\t\tvar noteDataToCheck",
        "\tfunction deleteNote(note:Note):Void\n\t{\n\t\t#if android\n\t\tmobileCheckpoint();\n\t\t#end\n\t\tvar noteDataToCheck")

    anchor = "\tvar lastConductorPos:Float;\n\tvar colorSine:Float = 0;\n\toverride function update(elapsed:Float)\n\t{"
    text = chart.read_text(encoding="utf-8")
    if text.count(anchor) != 1:
        raise SystemExit("Could not locate unique ChartingState.update integration anchor")
    adapter = r'''
	#if android
	public function mobileGetSong():SwagSong return _song;
	public function mobileGetSelectedNote():Array<Dynamic> return curSelectedNote;
	public function mobileGetSection():SwagSection return _song.notes[curSection];
	public function mobileChangeSection(delta:Int):Void {
		var target = curSection + delta;
		if (target < 0) target = 0;
		if (target >= _song.notes.length) { addSection(); target = _song.notes.length - 1; }
		changeSection(target);
	}
	public function mobileUndo():Void if (mobileBridge != null) mobileBridge.restoreUndo();
	public function mobileRedo():Void if (mobileBridge != null) mobileBridge.restoreRedo();
	public function mobileSetClassicUIVisible(value:Bool):Void {
		if (UI_box != null) UI_box.visible = value;
		if (_pad != null) _pad.visible = value;
		if (key_space != null) key_space.visible = value;
	}
	public function mobileDeleteSelected():Void {
		if (curSelectedNote == null) return;
		_song.notes[curSection].sectionNotes.remove(curSelectedNote);
		curSelectedNote = null;
		updateGrid(); updateNoteUI();
	}
	public function mobileCopySelected():Void if (curSelectedNote != null) mobileCopiedNote = curSelectedNote.copy();
	public function mobilePasteSelected():Void {
		if (mobileCopiedNote == null) return;
		var copy = mobileCopiedNote.copy(); copy[0] = Conductor.songPosition;
		_song.notes[curSection].sectionNotes.push(copy); curSelectedNote = copy;
		updateGrid(); updateNoteUI();
	}
	public function mobileChangeSelectedSustain(delta:Float):Void {
		if (curSelectedNote == null || curSelectedNote[1] < 0) return;
		var value:Float = curSelectedNote[2] == null ? 0 : curSelectedNote[2];
		value += delta; if (value < 0) value = 0; curSelectedNote[2] = value;
		updateGrid(); updateNoteUI();
	}
	public function mobileSetSongFields(name:String, ?bpm:Null<Float>, ?speed:Null<Float>):Void {
		if (name != null && name.length > 0) { _song.song = name; if (UI_songTitle != null) UI_songTitle.text = name; currentSongName = Paths.formatToSongPath(name); }
		if (bpm != null) { _song.bpm = bpm; tempBpm = bpm; Conductor.changeBPM(bpm); Conductor.mapBPMChanges(_song); }
		if (speed != null) _song.speed = speed;
		updateGrid();
	}
	public function mobileSetSongCharacter(slot:String, id:String):Void {
		switch(slot) { case 'bf': _song.player1 = id; case 'gf': _song.player3 = id; default: _song.player2 = id; }
		updateHeads();
	}
	public function mobileToggleSectionFlag(field:String):Void {
		var sec = _song.notes[curSection];
		switch(field) { case 'mustHitSection': sec.mustHitSection = !sec.mustHitSection; case 'gfSection': sec.gfSection = !sec.gfSection; case 'altAnim': sec.altAnim = !sec.altAnim; case 'changeBPM': sec.changeBPM = !sec.changeBPM; }
		updateGrid(); updateSectionUI();
	}
	public function mobileCopySection():Void { mobileCopiedSection = []; for (note in _song.notes[curSection].sectionNotes) mobileCopiedSection.push(note.copy()); }
	public function mobilePasteSection():Void {
		if (mobileCopiedSection == null) return;
		_song.notes[curSection].sectionNotes = []; for (note in mobileCopiedSection) _song.notes[curSection].sectionNotes.push(note.copy()); updateGrid();
	}
	public function mobileEventsForCurrentSection():Array<Array<Dynamic>> {
		var result:Array<Array<Dynamic>> = [];
		for (note in _song.notes[curSection].sectionNotes) if (note != null && note.length >= 5 && note[1] < 0) result.push(cast note);
		return result;
	}
	public function mobileAddEvent(name:String, value1:String, value2:String):Void {
		var event:Array<Dynamic> = [Conductor.songPosition, -1, name, value1, value2];
		_song.notes[curSection].sectionNotes.push(event); curSelectedNote = event; updateGrid(); updateNoteUI();
	}
	public function mobileUpdateEvent(event:Array<Dynamic>, name:String, value1:String, value2:String):Void {
		if (event == null) return; event[2] = name; event[3] = value1; event[4] = value2; curSelectedNote = event; updateGrid(); updateNoteUI();
	}
	public function mobileDeleteEvent(event:Array<Dynamic>):Void {
		_song.notes[curSection].sectionNotes.remove(event); if (curSelectedNote == event) curSelectedNote = null; updateGrid(); updateNoteUI();
	}
	public function mobileReplaceSong(song:SwagSong):Void {
		_song = song; PlayState.SONG = song; if (UI_songTitle != null) UI_songTitle.text = song.song; currentSongName = Paths.formatToSongPath(song.song);
		if (curSection >= _song.notes.length) curSection = _song.notes.length - 1; if (curSection < 0) curSection = 0;
		Conductor.mapBPMChanges(_song); Conductor.changeBPM(_song.bpm); updateGrid(); updateSectionUI(); updateHeads();
	}
	public function mobileSaveDirect():Void if (mobileBridge != null) mobileBridge.saveDirect();
	public function mobileOpenEventEditor():Void if (mobileBridge != null) mobileBridge.openEventEditor();
	public function mobileRefreshGrid():Void updateGrid();
	#end

'''
    chart.write_text(text.replace(anchor, adapter + anchor, 1), encoding="utf-8")

    replace_once(chart,
        "\tprivate function saveLevel()\n\t{\n\t\tvar json = {",
        "\tprivate function saveLevel()\n\t{\n\t\t#if android\n\t\tif (mobileBridge != null) { mobileBridge.saveDirect(); return; }\n\t\t#end\n\t\tvar json = {")

    song = engine / "source/Song.hx"
    replace_once(song,
        "\t\tif(FileSystem.exists(moddyFile)) {\n\t\t\trawJson = Assets.getText(moddyFile).trim();\n\t\t}",
        "\t\tif(FileSystem.exists(moddyFile)) {\n\t\t\trawJson = File.getContent(moddyFile).trim();\n\t\t}")

    print("Mobile editor integration patches applied successfully.")


if __name__ == "__main__":
    main()
