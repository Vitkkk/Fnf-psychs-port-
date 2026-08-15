#!/usr/bin/env python3
"""Small runtime compatibility patch for event capabilities exposed by the mobile editor."""
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_runtime_events.py <upstream-engine-dir>")

root = Path(sys.argv[1])
play = root / "source/PlayState.hx"
text = play.read_text(encoding="utf-8")
old = """\t\t\tcase 'Super Flash':
\t\t\t\tvar flashValue:Int = Std.parseInt(value1);

\t\t\t\tif (ClientPrefs.flashing)
\t\t\t\t\tFlxG.camera.flash(FlxColor.WHITE, flashValue);
\t\t\t\telse
\t\t\t\t\tFlxG.camera.flash(FlxColor.BLACK, flashValue);
"""
new = """\t\t\tcase 'Super Flash':
\t\t\t\t// Legacy charts used only Value 1 (duration). Mobile Creator keeps
\t\t\t\t// that behavior, but accepts Value 2 = HEX,opacity,ease.
\t\t\t\tvar flashDuration:Float = Std.parseFloat(value1);
\t\t\t\tif (Math.isNaN(flashDuration) || flashDuration <= 0) flashDuration = 0.5;
\t\t\t\tvar flashColor:Int = ClientPrefs.flashing ? FlxColor.WHITE : FlxColor.BLACK;
\t\t\t\tvar flashOpacity:Float = 1;
\t\t\t\tvar flashEase = FlxEase.linear;
\t\t\t\tif (value2 != null && value2.trim().length > 0) {
\t\t\t\t\tvar flashParts:Array<String> = value2.split(',');
\t\t\t\t\tif (flashParts.length > 0) {
\t\t\t\t\t\tvar hex = flashParts[0].trim().replace('#', '').replace('0x', '');
\t\t\t\t\t\tvar parsedColor:Null<Int> = Std.parseInt('0x' + hex);
\t\t\t\t\t\tif (parsedColor != null) flashColor = 0xFF000000 | parsedColor;
\t\t\t\t\t}
\t\t\t\t\tif (flashParts.length > 1) {
\t\t\t\t\t\tvar parsedOpacity = Std.parseFloat(flashParts[1].trim());
\t\t\t\t\t\tif (!Math.isNaN(parsedOpacity)) flashOpacity = FlxMath.bound(parsedOpacity, 0, 1);
\t\t\t\t\t}
\t\t\t\t\tif (flashParts.length > 2) {
\t\t\t\t\t\tswitch (flashParts[2].trim()) {
\t\t\t\t\t\t\tcase 'quadIn': flashEase = FlxEase.quadIn;
\t\t\t\t\t\t\tcase 'quadOut': flashEase = FlxEase.quadOut;
\t\t\t\t\t\t\tcase 'quadInOut': flashEase = FlxEase.quadInOut;
\t\t\t\t\t\t}
\t\t\t\t\t}
\t\t\t\t}
\t\t\t\tif (flashOpacity >= 0.999) {
\t\t\t\t\tFlxG.camera.flash(flashColor, flashDuration);
\t\t\t\t} else {
\t\t\t\t\tvar mobileFlash = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, flashColor);
\t\t\t\t\tmobileFlash.scrollFactor.set();
\t\t\t\t\tmobileFlash.alpha = flashOpacity;
\t\t\t\t\tmobileFlash.cameras = [camOther];
\t\t\t\t\tadd(mobileFlash);
\t\t\t\t\tFlxTween.tween(mobileFlash, {alpha: 0}, flashDuration, {ease: flashEase, onComplete: function(_) {
\t\t\t\t\t\tremove(mobileFlash, true);
\t\t\t\t\t\tmobileFlash.destroy();
\t\t\t\t\t}});
\t\t\t\t}
"""
if text.count(old) != 1:
    raise SystemExit(f"Super Flash patch anchor mismatch: {text.count(old)} matches")
play.write_text(text.replace(old, new, 1), encoding="utf-8")
print("Enhanced Super Flash event handler applied.")
