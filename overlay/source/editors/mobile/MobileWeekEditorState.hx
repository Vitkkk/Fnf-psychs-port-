package editors.mobile;

import editors.WeekEditorState;
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.FlxUIInputText;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
import WeekData;

using StringTools;

/**
 * Android-first Week Editor.  It writes ordinary WeekFile JSON and stores only
 * optional editor-only presentation metadata under `_mobileEditor`.
 */
class MobileWeekEditorState extends MusicBeatState
{
    static inline var TAB_GENERAL:Int = 0;
    static inline var TAB_CHARACTERS:Int = 1;
    static inline var TAB_SONGS:Int = 2;
    static inline var TAB_PREVIEW:Int = 3;

    var ui:FlxGroup;
    var weekFile:WeekFile;
    var weekId:String = '';
    var meta:Dynamic;
    var activeTab:Int = TAB_GENERAL;
    var listPage:Int = 0;

    var projectInput:FlxUIInputText;
    var internalInput:FlxUIInputText;
    var storyInput:FlxUIInputText;
    var weekNameInput:FlxUIInputText;
    var backgroundInput:FlxUIInputText;
    var status:FlxText;

    override function create():Void
    {
        FlxG.mouse.visible = true;
        FlxG.camera.bgColor = 0xFF11151D;
        ui = new FlxGroup();
        add(ui);

        var mods = MobileEditorFileSystem.listMods();
        if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
            MobileEditorFileSystem.currentMod = Paths.currentModDirectory;
        else if (mods.length > 0)
            MobileEditorFileSystem.currentMod = mods[0];
        else
            MobileEditorFileSystem.currentMod = '_mobile_project';
        MobileEditorFileSystem.ensureProject();

        showWeekList();
        super.create();
    }

    function clearUi():Void
    {
        if (internalInput != null) syncGeneralInputs();
        for (member in ui.members)
            if (member != null) member.destroy();
        ui.clear();
        projectInput = null;
        internalInput = null;
        storyInput = null;
        weekNameInput = null;
        backgroundInput = null;
        status = null;
    }

    function addText(text:String, x:Float, y:Float, width:Float, size:Int = 22, align:String = 'left'):FlxText
    {
        var t = new FlxText(x, y, width, text, size);
        var a = align == 'center' ? CENTER : LEFT;
        t.setFormat(Paths.font('vcr.ttf'), size, FlxColor.WHITE, a);
        t.scrollFactor.set();
        ui.add(t);
        return t;
    }

    function setupInput(input:FlxUIInputText):Void
    {
        input.focusGained = function() FlxG.stage.window.textInputEnabled = true;
        input.focusLost = function() FlxG.stage.window.textInputEnabled = false;
        ui.add(input);
    }

    function showWeekList():Void
    {
        clearUi();
        activeTab = TAB_GENERAL;
        addText('WEEK EDITOR MOBILE', 24, 18, FlxG.width - 48, 32, 'center');
        ui.add(new MobileButton(24, 16, 130, 48, '< VOLTAR', function() MusicBeatState.switchState(new MasterEditorMenu())));

        addText('Projeto atual', 32, 82, 220, 18);
        projectInput = new FlxUIInputText(32, 108, FlxG.width - 250, MobileEditorFileSystem.currentMod, 22);
        setupInput(projectInput);
        ui.add(new MobileButton(FlxG.width - 205, 99, 173, 54, 'ABRIR / CRIAR', function() {
            var name = projectInput.text.trim();
            if (name.length == 0) return;
            MobileEditorFileSystem.currentMod = name;
            MobileEditorFileSystem.ensureProject();
            listPage = 0;
            showWeekList();
        }));

        ui.add(new MobileButton(32, 172, FlxG.width - 64, 64, '+ CRIAR WEEK', createNewWeek));

        var weeks = MobileEditorFileSystem.listWeekFiles();
        var pageSize = 5;
        var start = listPage * pageSize;
        var end = Std.int(Math.min(weeks.length, start + pageSize));
        for (i in start...end)
        {
            var id = weeks[i];
            var y = 258 + (i - start) * 76;
            var summary = weekSummary(id);
            ui.add(new MobileButton(36, y, FlxG.width - 72, 64, summary, function() loadWeek(id)));
        }

        if (weeks.length == 0)
            addText('Nenhuma week neste mod. Toque em + CRIAR WEEK.', 40, 292, FlxG.width - 80, 22, 'center');

        ui.add(new MobileButton(32, FlxG.height - 66, 170, 48, '< PÁGINA', function() {
            if (listPage > 0) { listPage--; showWeekList(); }
        }));
        ui.add(new MobileButton(FlxG.width - 202, FlxG.height - 66, 170, 48, 'PÁGINA >', function() {
            if ((listPage + 1) * pageSize < weeks.length) { listPage++; showWeekList(); }
        }));
    }

    function weekSummary(id:String):String
    {
        var file = readWeek(id);
        if (file == null) return id;
        return file.storyName + '    •    ' + file.songs.length + ' músicas';
    }

    function createNewWeek():Void
    {
        weekFile = WeekData.createWeekFile();
        weekFile.songs = [];
        weekId = 'minha-week';
        meta = makeMeta();
        activeTab = TAB_GENERAL;
        showEditor();
    }

    function loadWeek(id:String):Void
    {
        var loaded = readWeek(id);
        if (loaded == null) return;
        weekFile = loaded;
        weekId = id;
        meta = Reflect.field(cast weekFile, '_mobileEditor');
        if (meta == null) meta = makeMeta();
        activeTab = TAB_GENERAL;
        showEditor();
    }

    function readWeek(id:String):Null<WeekFile>
    {
        #if sys
        var modPath = MobileEditorFileSystem.weekPath(id);
        var paths = [modPath, 'assets/weeks/' + id + '.json'];
        for (path in paths)
        {
            if (!FileSystem.exists(path)) continue;
            try return cast Json.parse(File.getContent(path)) catch (e:Dynamic) trace(e);
        }
        #end
        return null;
    }

    function makeMeta():Dynamic
    {
        return {
            titleMode: 'image',
            titleImage: weekId,
            titleFont: 'vcr.ttf',
            titleFontSize: 42,
            songDifficulties: {}
        };
    }

    function showEditor():Void
    {
        clearUi();
        drawTopBar();
        drawTabs();
        switch (activeTab)
        {
            case TAB_CHARACTERS: drawCharactersTab();
            case TAB_SONGS: drawSongsTab();
            case TAB_PREVIEW: drawPreviewTab();
            default: drawGeneralTab();
        }
    }

    function drawTopBar():Void
    {
        ui.add(new MobileButton(18, 14, 118, 48, '< WEEK', showWeekList));
        addText(weekFile.storyName, 150, 18, FlxG.width - 500, 28, 'center');
        ui.add(new MobileButton(FlxG.width - 336, 14, 145, 48, 'SALVAR', saveWeekDirect));
        ui.add(new MobileButton(FlxG.width - 180, 14, 162, 48, 'CLÁSSICO', function() {
            syncGeneralInputs();
            WeekEditorState.weekFileName = weekId;
            MusicBeatState.switchState(new WeekEditorState(weekFile));
        }));
    }

    function drawTabs():Void
    {
        var labels = ['GERAL', 'PERSONAGENS', 'MÚSICAS', 'PREVIEW'];
        var w = (FlxG.width - 36) / labels.length;
        for (i in 0...labels.length)
        {
            var button:MobileButton = null;
            button = new MobileButton(18 + i * w, 74, w - 5, 52, labels[i], function() {
                syncGeneralInputs();
                activeTab = i;
                showEditor();
            });
            button.setSelected(activeTab == i);
            ui.add(button);
        }
    }

    function drawGeneralTab():Void
    {
        var y:Float = 150;
        addText('Nome interno', 40, y, 230, 18); y += 26;
        internalInput = new FlxUIInputText(40, y, FlxG.width - 80, weekId, 22); setupInput(internalInput); y += 64;

        addText('Título exibido', 40, y, 230, 18); y += 26;
        storyInput = new FlxUIInputText(40, y, FlxG.width - 80, weekFile.storyName, 22); setupInput(storyInput); y += 64;

        addText('Nome da Week / score', 40, y, 300, 18); y += 26;
        weekNameInput = new FlxUIInputText(40, y, FlxG.width - 80, weekFile.weekName, 22); setupInput(weekNameInput); y += 64;

        addText('Background', 40, y, 230, 18); y += 26;
        backgroundInput = new FlxUIInputText(40, y, FlxG.width - 80, weekFile.weekBackground, 22); setupInput(backgroundInput); y += 66;

        var mode = Std.string(Reflect.field(meta, 'titleMode'));
        addText('Método do título', 40, y, 260, 18);
        ui.add(new MobileButton(310, y - 10, 220, 48, mode == 'text' ? 'TEXTO / FONTE' : 'IMAGEM', function() {
            Reflect.setField(meta, 'titleMode', mode == 'text' ? 'image' : 'text');
            showEditor();
        }));

        if (mode == 'text')
        {
            var fonts = MobileEditorFileSystem.listFonts();
            var currentFont = Std.string(Reflect.field(meta, 'titleFont'));
            ui.add(new MobileButton(550, y - 10, FlxG.width - 590, 48, 'Fonte: ' + currentFont, function() {
                if (fonts.length == 0) return;
                var idx = fonts.indexOf(currentFont);
                idx = (idx + 1) % fonts.length;
                Reflect.setField(meta, 'titleFont', fonts[idx]);
                showEditor();
            }));
        }
        else
        {
            var imageId = Std.string(Reflect.field(meta, 'titleImage'));
            ui.add(new MobileButton(550, y - 10, FlxG.width - 590, 48, 'Imagem: ' + imageId, function() {
                Reflect.setField(meta, 'titleImage', weekId);
                showEditor();
            }));
        }

        status = addText('Salvar grava diretamente em ' + MobileEditorFileSystem.weekPath(weekId), 40, FlxG.height - 42, FlxG.width - 80, 15, 'center');
        status.color = 0xFF9BA7BA;
    }

    function syncGeneralInputs():Void
    {
        if (weekFile == null) return;
        if (internalInput != null) weekId = MobileEditorFileSystem.sanitizeId(internalInput.text);
        if (storyInput != null) weekFile.storyName = storyInput.text.trim();
        if (weekNameInput != null) weekFile.weekName = weekNameInput.text.trim();
        if (backgroundInput != null) weekFile.weekBackground = backgroundInput.text.trim();
    }

    function drawCharactersTab():Void
    {
        var labels = ['OPPONENT', 'PLAYER', 'GF'];
        for (i in 0...3)
        {
            var x = 44 + i * ((FlxG.width - 88) / 3);
            var w = (FlxG.width - 120) / 3;
            addText(labels[i], x, 158, w, 22, 'center');
            var id = weekFile.weekCharacters[i];
            var icon = new HealthIcon(id);
            icon.setGraphicSize(0, 120);
            icon.updateHitbox();
            icon.setPosition(x + (w - icon.width) / 2, 215);
            icon.scrollFactor.set();
            ui.add(icon);
            addText(id, x, 348, w, 18, 'center');
            ui.add(new MobileButton(x, 390, w, 58, 'ALTERAR', function() {
                openSubState(new MobileCharacterPickerSubState(function(selected:String) {
                    weekFile.weekCharacters[i] = selected;
                    showEditor();
                }));
            }));
        }
        addText('O picker pesquisa characters do mod atual + assets padrão e mostra thumbnail pelo health icon.', 50, 500, FlxG.width - 100, 18, 'center');
    }

    function drawSongsTab():Void
    {
        ui.add(new MobileButton(38, 144, FlxG.width - 76, 58, '+ ADICIONAR MÚSICA', function() {
            openSubState(new MobileSongEditorSubState(null, function(result:MobileWeekSongEdit) {
                weekFile.songs.push([result.displayName, weekFile.weekCharacters[0], [146, 113, 253], result.internalName]);
                setSongDifficulties(result.internalName, result.difficulties);
                showEditor();
            }));
        }));

        var maxVisible = 5;
        for (i in 0...Std.int(Math.min(weekFile.songs.length, maxVisible)))
        {
            var song = weekFile.songs[i];
            var display = Std.string(song[0]);
            var internal = song.length > 3 ? Std.string(song[3]) : Paths.formatToSongPath(display);
            var diffs = getSongDifficulties(internal);
            var y = 220 + i * 84;
            addText(display + '   [' + internal + ']\n' + diffs.join(' • '), 46, y + 4, FlxG.width - 430, 18);
            ui.add(new MobileButton(FlxG.width - 370, y, 76, 62, '↑', function() moveSong(i, -1)));
            ui.add(new MobileButton(FlxG.width - 286, y, 76, 62, '↓', function() moveSong(i, 1)));
            ui.add(new MobileButton(FlxG.width - 202, y, 80, 62, 'EDIT', function() editSong(i)));
            ui.add(new MobileButton(FlxG.width - 114, y, 76, 62, '×', function() {
                weekFile.songs.splice(i, 1);
                showEditor();
            }));
        }
        if (weekFile.songs.length > maxVisible)
            addText('+' + (weekFile.songs.length - maxVisible) + ' músicas. O Milestone 1 usa paginação compacta; ordem completa é preservada.', 50, FlxG.height - 48, FlxG.width - 100, 16, 'center');
    }

    function editSong(index:Int):Void
    {
        var song = weekFile.songs[index];
        var display = Std.string(song[0]);
        var internal = song.length > 3 ? Std.string(song[3]) : Paths.formatToSongPath(display);
        var existing:MobileWeekSongEdit = {displayName: display, internalName: internal, difficulties: getSongDifficulties(internal)};
        openSubState(new MobileSongEditorSubState(existing, function(result:MobileWeekSongEdit) {
            song[0] = result.displayName;
            if (song.length > 3) song[3] = result.internalName; else song.push(result.internalName);
            setSongDifficulties(result.internalName, result.difficulties);
            showEditor();
        }));
    }

    function moveSong(index:Int, delta:Int):Void
    {
        var target = index + delta;
        if (target < 0 || target >= weekFile.songs.length) return;
        var item = weekFile.songs[index];
        weekFile.songs[index] = weekFile.songs[target];
        weekFile.songs[target] = item;
        showEditor();
    }

    function difficultyObject():Dynamic
    {
        var obj = Reflect.field(meta, 'songDifficulties');
        if (obj == null)
        {
            obj = {};
            Reflect.setField(meta, 'songDifficulties', obj);
        }
        return obj;
    }

    function getSongDifficulties(id:String):Array<String>
    {
        var obj = difficultyObject();
        var value:Dynamic = Reflect.field(obj, id);
        if (value == null) return ['Easy', 'Normal', 'Hard'];
        return cast value;
    }

    function setSongDifficulties(id:String, value:Array<String>):Void
    {
        Reflect.setField(difficultyObject(), id, value.copy());
    }

    function drawPreviewTab():Void
    {
        var panel = new FlxSprite(40, 150).makeGraphic(FlxG.width - 80, FlxG.height - 210, 0xFF242A36);
        panel.scrollFactor.set();
        ui.add(panel);

        var mode = Std.string(Reflect.field(meta, 'titleMode'));
        var title = new FlxText(70, 175, FlxG.width - 140, weekFile.storyName.toUpperCase(), Std.int(Reflect.field(meta, 'titleFontSize')));
        var font = mode == 'text' ? Std.string(Reflect.field(meta, 'titleFont')) : 'vcr.ttf';
        var fontPath = font.indexOf('/') != -1 ? font : Paths.font(font);
        title.setFormat(fontPath, 38, FlxColor.WHITE, CENTER);
        ui.add(title);

        for (i in 0...3)
        {
            var icon = new HealthIcon(weekFile.weekCharacters[i]);
            icon.setGraphicSize(0, 92);
            icon.updateHitbox();
            icon.setPosition(140 + i * ((FlxG.width - 280) / 3), 250);
            icon.scrollFactor.set();
            ui.add(icon);
        }

        var songs:Array<String> = [];
        for (song in weekFile.songs) songs.push(Std.string(song[0]));
        var songText = songs.length == 0 ? '(sem músicas)' : songs.join('\n');
        addText(songText.toUpperCase(), 100, 372, FlxG.width - 200, 24, 'center');
        addText('Preview leve: título • personagens • tracklist. Não inicia o PlayState.', 70, FlxG.height - 70, FlxG.width - 140, 17, 'center');
    }

    function saveWeekDirect():Void
    {
        syncGeneralInputs();
        Reflect.setField(cast weekFile, '_mobileEditor', meta);
        var data = Json.stringify(weekFile, '\t');
        MobileEditorFileSystem.ensureProject();
        var ok = MobileEditorFileSystem.safeWriteJson(MobileEditorFileSystem.weekPath(weekId), data);
        MobileEditorFileSystem.saveAutosave('week', weekId, data);
        MobileEditorFileSystem.ensureWeekListed(weekId);
        if (status != null)
        {
            status.text = ok ? 'SALVO: ' + MobileEditorFileSystem.weekPath(weekId) : 'ERRO AO SALVAR';
            status.color = ok ? 0xFF7CFF9A : 0xFFFF6F6F;
        }
        FlxG.sound.play(Paths.sound(ok ? 'confirmMenu' : 'cancelMenu'));
    }
}
