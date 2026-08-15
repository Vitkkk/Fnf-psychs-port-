package editors.mobile;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.ui.FlxUIInputText;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/** Searchable, paged character picker with icon thumbnails. */
class MobileCharacterPickerSubState extends FlxSubState
{
    public var onSelected:String->Void;

    var search:FlxUIInputText;
    var page:Int = 0;
    var pageText:FlxText;
    var all:Array<String> = [];
    var filtered:Array<String> = [];
    var dynamicItems:Array<Dynamic> = [];
    var lastQuery:String = '';
    static inline var PAGE_SIZE:Int = 10;

    public function new(callback:String->Void)
    {
        super(0xCC10131A);
        onSelected = callback;
    }

    override function create():Void
    {
        super.create();
        var title = new FlxText(24, 18, FlxG.width - 48, 'SELECIONAR PERSONAGEM', 30);
        title.setFormat(Paths.font('vcr.ttf'), 30, FlxColor.WHITE, CENTER);
        title.scrollFactor.set();
        add(title);

        search = new FlxUIInputText(32, 64, FlxG.width - 64, '', 22);
        search.focusGained = function() FlxG.stage.window.textInputEnabled = true;
        search.focusLost = function() FlxG.stage.window.textInputEnabled = false;
        add(search);

        all = MobileEditorFileSystem.listCharacters();
        filtered = all.copy();

        var prev = new MobileButton(32, FlxG.height - 70, 170, 52, '< ANTERIOR', function() {
            if (page > 0) { page--; refresh(); }
        });
        add(prev);

        pageText = new FlxText(220, FlxG.height - 60, FlxG.width - 440, '', 20);
        pageText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, CENTER);
        add(pageText);

        var next = new MobileButton(FlxG.width - 202, FlxG.height - 70, 170, 52, 'PRÓXIMA >', function() {
            var max = Std.int(Math.max(0, Math.ceil(filtered.length / PAGE_SIZE) - 1));
            if (page < max) { page++; refresh(); }
        });
        add(next);

        var close = new MobileButton(FlxG.width - 170, 12, 138, 44, 'CANCELAR', function() close());
        add(close);
        refresh();
    }

    override function update(elapsed:Float):Void
    {
        if (search.text != lastQuery)
        {
            lastQuery = search.text;
            var q = lastQuery.trim().toLowerCase();
            filtered = [];
            for (name in all)
                if (q.length == 0 || name.toLowerCase().indexOf(q) != -1) filtered.push(name);
            page = 0;
            refresh();
        }
        super.update(elapsed);
    }

    function refresh():Void
    {
        for (item in dynamicItems)
        {
            remove(item, true);
            item.destroy();
        }
        dynamicItems = [];

        var start = page * PAGE_SIZE;
        var end = Std.int(Math.min(filtered.length, start + PAGE_SIZE));
        var cardW = (FlxG.width - 84) / 2;
        var rowH:Float = 92;

        for (i in start...end)
        {
            var local = i - start;
            var col = local % 2;
            var row = Std.int(local / 2);
            var x = 28 + col * (cardW + 28);
            var y = 112 + row * rowH;
            var id = filtered[i];

            var button = new MobileButton(x, y, cardW, 76, id, function() {
                if (onSelected != null) onSelected(id);
                close();
            });
            add(button);
            dynamicItems.push(button);

            var icon:HealthIcon = new HealthIcon(characterIcon(id));
            icon.setGraphicSize(0, 58);
            icon.updateHitbox();
            icon.setPosition(x + 8, y + 9);
            icon.scrollFactor.set();
            add(icon);
            dynamicItems.push(icon);
        }

        var pages = Std.int(Math.max(1, Math.ceil(filtered.length / PAGE_SIZE)));
        pageText.text = (page + 1) + ' / ' + pages + '   (' + filtered.length + ')';
    }

    static function characterIcon(id:String):String
    {
        #if sys
        var candidates = [
            MobileEditorFileSystem.currentModRoot() + 'characters/' + id + '.json',
            'assets/characters/' + id + '.json'
        ];
        for (path in candidates)
        {
            if (!FileSystem.exists(path)) continue;
            try
            {
                var data:Dynamic = Json.parse(File.getContent(path));
                if (Reflect.hasField(data, 'healthicon'))
                {
                    var icon = Std.string(Reflect.field(data, 'healthicon'));
                    if (icon != null && icon.length > 0) return icon;
                }
            }
            catch (e:Dynamic) {}
        }
        #end
        return id;
    }
}
