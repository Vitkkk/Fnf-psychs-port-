package editors.mobile;

import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * Centralizes editor persistence so UI code never has to know Android paths.
 * The engine's existing Main.path remains the storage authority.
 */
class MobileEditorFileSystem
{
    public static var currentMod(default, set):String = '';
    public static var autosaveEnabled:Bool = true;

    static function set_currentMod(value:String):String
    {
        currentMod = sanitizeFolder(value);
        Paths.currentModDirectory = currentMod;
        return currentMod;
    }

    public static function modsRoot():String
    {
        return Main.path + 'mods/';
    }

    public static function currentModRoot():String
    {
        var mod = currentMod;
        if (mod == null || mod.length == 0) mod = '_mobile_project';
        return modsRoot() + mod + '/';
    }

    public static function ensureProject():Void
    {
        #if sys
        ensureDir(modsRoot());
        ensureDir(currentModRoot());
        ensureDir(currentModRoot() + 'weeks/');
        ensureDir(currentModRoot() + 'data/');
        ensureDir(currentModRoot() + 'images/');
        ensureDir(currentModRoot() + 'characters/');
        ensureDir(currentModRoot() + 'fonts/');
        ensureDir(currentModRoot() + '.editor/autosaves/');
        #end
    }

    public static function listMods():Array<String>
    {
        var out:Array<String> = [];
        #if sys
        ensureDir(modsRoot());
        for (entry in FileSystem.readDirectory(modsRoot()))
        {
            var full = modsRoot() + entry;
            if (FileSystem.isDirectory(full) && !entry.startsWith('.')) out.push(entry);
        }
        #end
        out.sort(function(a:String, b:String):Int return Reflect.compare(a.toLowerCase(), b.toLowerCase()));
        return out;
    }

    public static function listWeekFiles():Array<String>
    {
        var out:Array<String> = [];
        #if sys
        var dir = currentModRoot() + 'weeks/';
        ensureDir(dir);
        for (entry in FileSystem.readDirectory(dir))
            if (entry.toLowerCase().endsWith('.json')) out.push(entry.substr(0, entry.length - 5));
        #end
        out.sort(function(a:String, b:String):Int return Reflect.compare(a.toLowerCase(), b.toLowerCase()));
        return out;
    }

    public static function listCharacters():Array<String>
    {
        var seen:Map<String, Bool> = new Map();
        var out:Array<String> = [];
        #if sys
        var modDir = currentModRoot() + 'characters/';
        if (FileSystem.exists(modDir))
        {
            for (entry in FileSystem.readDirectory(modDir))
                if (entry.toLowerCase().endsWith('.json')) addUnique(entry.substr(0, entry.length - 5), seen, out);
        }
        var baseDir = 'assets/characters/';
        if (FileSystem.exists(baseDir))
        {
            for (entry in FileSystem.readDirectory(baseDir))
                if (entry.toLowerCase().endsWith('.json')) addUnique(entry.substr(0, entry.length - 5), seen, out);
        }
        #end
        out.sort(function(a:String, b:String):Int return Reflect.compare(a.toLowerCase(), b.toLowerCase()));
        return out;
    }

    public static function listFonts():Array<String>
    {
        var seen:Map<String, Bool> = new Map();
        var out:Array<String> = [];
        #if sys
        scanExtensions(currentModRoot() + 'fonts/', ['ttf', 'otf'], seen, out);
        scanExtensions('assets/fonts/', ['ttf', 'otf'], seen, out);
        #end
        out.sort(function(a:String, b:String):Int return Reflect.compare(a.toLowerCase(), b.toLowerCase()));
        return out;
    }

    public static function weekPath(id:String):String
    {
        return currentModRoot() + 'weeks/' + sanitizeId(id) + '.json';
    }

    public static function songPath(song:String, ?difficulty:String = ''):String
    {
        var songId = Paths.formatToSongPath(song);
        var suffix = '';
        if (difficulty != null)
        {
            var diff = difficulty.trim().toLowerCase();
            if (diff.length > 0 && diff != 'normal') suffix = '-' + sanitizeId(diff);
        }
        return currentModRoot() + 'data/' + songId + '/' + songId + suffix + '.json';
    }

    public static function safeWriteJson(path:String, json:String):Bool
    {
        #if sys
        try
        {
            var parsed:Dynamic = Json.parse(json);
            if (parsed == null) return false;
            ensureDir(parent(path));
            var tmp = path + '.tmp';
            var backup = path + '.bak';
            File.saveContent(tmp, json);
            Json.parse(File.getContent(tmp));
            if (FileSystem.exists(path))
            {
                if (FileSystem.exists(backup)) FileSystem.deleteFile(backup);
                File.copy(path, backup);
                FileSystem.deleteFile(path);
            }
            FileSystem.rename(tmp, path);
            return true;
        }
        catch (e:Dynamic)
        {
            trace('MobileEditorFileSystem.safeWriteJson failed: ' + Std.string(e));
            return false;
        }
        #else
        return false;
        #end
    }

    public static function saveAutosave(kind:String, id:String, json:String):Bool
    {
        if (!autosaveEnabled) return false;
        #if sys
        ensureProject();
        var safeKind = sanitizeId(kind);
        var safeId = sanitizeId(id);
        var path = currentModRoot() + '.editor/autosaves/' + safeKind + '-' + safeId + '.json';
        return safeWriteJson(path, json);
        #else
        return false;
        #end
    }

    public static function readText(path:String):Null<String>
    {
        #if sys
        if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) return File.getContent(path);
        #end
        return null;
    }

    public static function copyIntoCurrentMod(source:String, relativeTarget:String):Null<String>
    {
        #if sys
        try
        {
            var target = currentModRoot() + relativeTarget;
            ensureDir(parent(target));
            File.copy(source, target);
            return target;
        }
        catch (e:Dynamic)
        {
            trace('copyIntoCurrentMod failed: ' + Std.string(e));
        }
        #end
        return null;
    }

    static function addUnique(value:String, seen:Map<String, Bool>, out:Array<String>):Void
    {
        var key = value.toLowerCase();
        if (!seen.exists(key))
        {
            seen.set(key, true);
            out.push(value);
        }
    }

    #if sys
    static function scanExtensions(dir:String, exts:Array<String>, seen:Map<String, Bool>, out:Array<String>):Void
    {
        if (!FileSystem.exists(dir)) return;
        for (entry in FileSystem.readDirectory(dir))
        {
            var lower = entry.toLowerCase();
            for (ext in exts)
                if (lower.endsWith('.' + ext)) addUnique(entry, seen, out);
        }
    }

    static function ensureDir(path:String):Void
    {
        if (path == null || path.length == 0 || FileSystem.exists(path)) return;
        var p = parent(path);
        if (p != path && p.length > 0) ensureDir(p);
        if (!FileSystem.exists(path)) FileSystem.createDirectory(path);
    }
    #end

    static function parent(path:String):String
    {
        var clean = path.replace('\\', '/');
        while (clean.endsWith('/')) clean = clean.substr(0, clean.length - 1);
        var slash = clean.lastIndexOf('/');
        return slash < 0 ? '' : clean.substr(0, slash + 1);
    }

    static function sanitizeFolder(value:String):String
    {
        if (value == null) return '';
        return value.trim().replace('..', '').replace('/', '-').replace('\\', '-');
    }

    public static function sanitizeId(value:String):String
    {
        if (value == null) return 'untitled';
        var out = value.trim().toLowerCase();
        out = out.replace(' ', '-').replace('/', '-').replace('\\', '-').replace('..', '-');
        while (out.indexOf('--') != -1) out = out.replace('--', '-');
        if (out.length == 0) out = 'untitled';
        return out;
    }
}
