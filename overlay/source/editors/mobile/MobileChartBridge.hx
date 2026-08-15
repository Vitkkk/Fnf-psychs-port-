package editors.mobile;

import editors.ChartingState;
import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.addons.ui.FlxUIInputText;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import Song.SwagSong;
import Section.SwagSection;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * Mobile-only presentation/controller layer over the existing ChartingState.
 * All chart data remains the native Psych SwagSong/SwagSection structures.
 */
class MobileChartBridge extends FlxSpriteGroup
{
    public var chart(default, null):ChartingState;

    var undoStack:Array<String> = [];
    var redoStack:Array<String> = [];
    var status:FlxText;
    var panelItems:Array<Dynamic> = [];
    var currentPanel:String = 'chart';
    var songNameInput:FlxUIInputText;
    var bpmInput:FlxUIInputText;
    var speedInput:FlxUIInputText;

    static inline var MAX_HISTORY:Int = 40;

    public function new(chart:ChartingState)
    {
        super();
        this.chart = chart;
        scrollFactor.set();
        chart.mobileSetClassicUIVisible(false);
        checkpoint();
        buildShell();
    }

    function buildShell():Void
    {
        add(new MobileButton(12, 10, 126, 48, '< SECTION', function() chart.mobileChangeSection(-1)));
        add(new MobileButton(146, 10, 126, 48, 'SECTION >', function() chart.mobileChangeSection(1)));
        add(new MobileButton(280, 10, 110, 48, '↶ UNDO', restoreUndo));
        add(new MobileButton(398, 10, 110, 48, '↷ REDO', restoreRedo));
        add(new MobileButton(FlxG.width - 338, 10, 154, 48, 'SALVAR', saveDirect));
        add(new MobileButton(FlxG.width - 176, 10, 164, 48, '+ EVENTO', openEventEditor));

        status = new FlxText(520, 18, FlxG.width - 880, '', 18);
        status.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER);
        status.scrollFactor.set();
        add(status);

        var labels = ['CHART', 'SONG', 'SECTION', 'EVENTS', 'CLÁSSICO'];
        var panelKeys = ['chart', 'song', 'section', 'events', 'classic'];
        var w = FlxG.width / labels.length;
        for (i in 0...labels.length)
        {
            var key = panelKeys[i];
            var button:MobileButton = null;
            button = new MobileButton(i * w, FlxG.height - 58, w - 4, 58, labels[i], function() {
                if (key == 'classic')
                {
                    chart.mobileSetClassicUIVisible(true);
                    clearPanel();
                    currentPanel = 'classic';
                }
                else
                {
                    chart.mobileSetClassicUIVisible(false);
                    showPanel(key);
                }
            });
            add(button);
        }
        showPanel('chart');
    }

    public function showPanel(key:String):Void
    {
        currentPanel = key;
        clearPanel();
        switch (key)
        {
            case 'song': drawSongPanel();
            case 'section': drawSectionPanel();
            case 'events': drawEventsPanel();
            default: drawChartPanel();
        }
    }

    function clearPanel():Void
    {
        for (item in panelItems)
        {
            remove(item, true);
            item.destroy();
        }
        panelItems = [];
        songNameInput = null;
        bpmInput = null;
        speedInput = null;
    }

    function panelAdd(item:Dynamic):Void
    {
        add(item);
        panelItems.push(item);
    }

    function panelText(text:String, x:Float, y:Float, width:Float, size:Int = 18, ?center:Bool = false):FlxText
    {
        var t = new FlxText(x, y, width, text, size);
        t.setFormat(Paths.font('vcr.ttf'), size, FlxColor.WHITE, center ? CENTER : LEFT);
        t.scrollFactor.set();
        panelAdd(t);
        return t;
    }

    function drawChartPanel():Void
    {
        var y = FlxG.height - 126;
        panelAdd(new MobileButton(12, y, 150, 54, 'EXCLUIR NOTA', function() {
            if (chart.mobileGetSelectedNote() == null) return;
            checkpoint();
            chart.mobileDeleteSelected();
        }));
        panelAdd(new MobileButton(170, y, 130, 54, 'COPIAR', function() chart.mobileCopySelected()));
        panelAdd(new MobileButton(308, y, 130, 54, 'COLAR', function() {
            checkpoint();
            chart.mobilePasteSelected();
        }));
        panelAdd(new MobileButton(446, y, 180, 54, 'SUSTAIN +', function() {
            checkpoint();
            chart.mobileChangeSelectedSustain(Conductor.stepCrochet * 0.5);
        }));
        panelAdd(new MobileButton(634, y, 180, 54, 'SUSTAIN -', function() {
            checkpoint();
            chart.mobileChangeSelectedSustain(-Conductor.stepCrochet * 0.5);
        }));
        panelText('Toque no grid para criar/selecionar. Os controles grandes abaixo substituem as ações mais difíceis no touch.', 828, y + 4, FlxG.width - 840, 15, true);
    }

    function drawSongPanel():Void
    {
        var song = chart.mobileGetSong();
        var top = 84;
        panelText('SONG', 24, top, 110, 24);

        panelText('Nome', 24, top + 36, 100, 16);
        songNameInput = makeInput(120, top + 28, 260, song.song);
        panelText('BPM', 398, top + 36, 70, 16);
        bpmInput = makeInput(466, top + 28, 120, Std.string(song.bpm));
        panelText('Speed', 606, top + 36, 80, 16);
        speedInput = makeInput(690, top + 28, 120, Std.string(song.speed));
        panelAdd(new MobileButton(824, top + 24, 150, 50, 'APLICAR', applySongFields));

        var chars = [
            {label:'PLAYER', slot:'bf', id:song.player1},
            {label:'OPPONENT', slot:'dad', id:song.player2},
            {label:'GF', slot:'gf', id:song.player3}
        ];
        for (i in 0...chars.length)
        {
            var c = chars[i];
            var x = 30 + i * 315;
            panelText(c.label, x, top + 105, 285, 17, true);
            panelAdd(new MobileButton(x, top + 132, 285, 56, c.id + '  • ALTERAR', function() {
                FlxG.state.openSubState(new MobileCharacterPickerSubState(function(selected:String) {
                    checkpoint();
                    chart.mobileSetSongCharacter(c.slot, selected);
                    showPanel('song');
                }));
            }));
        }

        panelText('Projeto: ' + MobileEditorFileSystem.currentMod + '   •   JSON: ' + MobileEditorFileSystem.songPath(song.song), 30, top + 214, FlxG.width - 60, 15, true);
    }

    function makeInput(x:Float, y:Float, width:Float, value:String):FlxUIInputText
    {
        var input = new FlxUIInputText(x, y, width, value, 21);
        input.focusGained = function() FlxG.stage.window.textInputEnabled = true;
        input.focusLost = function() FlxG.stage.window.textInputEnabled = false;
        panelAdd(input);
        return input;
    }

    function applySongFields():Void
    {
        checkpoint();
        var bpm = Std.parseFloat(bpmInput.text);
        var speed = Std.parseFloat(speedInput.text);
        chart.mobileSetSongFields(songNameInput.text.trim(), Math.isNaN(bpm) ? null : bpm, Math.isNaN(speed) ? null : speed);
        statusMessage('Song atualizado');
    }

    function drawSectionPanel():Void
    {
        var section = chart.mobileGetSection();
        var top = 92;
        panelText('SECTION', 24, top, 180, 24);
        panelText('Controles da seção atual', 24, top + 36, 280, 17);

        var flags = [
            {label:'MUST HIT', field:'mustHitSection', value:section.mustHitSection},
            {label:'GF SECTION', field:'gfSection', value:section.gfSection},
            {label:'ALT ANIMATION', field:'altAnim', value:section.altAnim},
            {label:'CHANGE BPM', field:'changeBPM', value:section.changeBPM}
        ];
        for (i in 0...flags.length)
        {
            var f = flags[i];
            var x = 30 + (i % 2) * 300;
            var y = top + 78 + Std.int(i / 2) * 72;
            var button:MobileButton = null;
            button = new MobileButton(x, y, 270, 56, f.label + ': ' + (f.value ? 'ON' : 'OFF'), function() {
                checkpoint();
                chart.mobileToggleSectionFlag(f.field);
                showPanel('section');
            });
            button.setSelected(f.value);
            panelAdd(button);
        }

        panelAdd(new MobileButton(650, top + 78, 230, 56, 'COPIAR SECTION', function() chart.mobileCopySection()));
        panelAdd(new MobileButton(650, top + 150, 230, 56, 'COLAR SECTION', function() {
            checkpoint();
            chart.mobilePasteSection();
        }));
        panelText('BPM da seção: ' + section.bpm + '   •   Steps: ' + section.lengthInSteps, 650, top + 228, 360, 18);
    }

    function drawEventsPanel():Void
    {
        var events = chart.mobileEventsForCurrentSection();
        panelAdd(new MobileButton(28, 86, FlxG.width - 56, 54, '+ ADICIONAR EVENTO', openEventEditor));
        if (events.length == 0)
        {
            panelText('Nenhum evento nesta section.', 40, 165, FlxG.width - 80, 22, true);
            return;
        }

        var max = Std.int(Math.min(events.length, 5));
        for (i in 0...max)
        {
            var event = events[i];
            var y = 154 + i * 76;
            var name = Std.string(event[2]);
            var summary = eventSummary(event);
            panelAdd(new MobileButton(34, y, FlxG.width - 210, 62, formatTime(event[0]) + '   ' + name + '   •   ' + summary, function() {
                FlxG.state.openSubState(new MobileEventEditorSubState(this, event));
            }));
            panelAdd(new MobileButton(FlxG.width - 164, y, 130, 62, 'EXCLUIR', function() {
                checkpoint();
                chart.mobileDeleteEvent(event);
                showPanel('events');
            }));
        }
    }

    function eventSummary(event:Array<Dynamic>):String
    {
        var def = MobileEventRegistry.findByEngineName(Std.string(event[2]));
        if (def == null) return 'V1=' + Std.string(event[3]) + '  V2=' + Std.string(event[4]);
        if (def.engineName == 'Change Character') return MobileEventRegistry.normalizeSlot(Std.string(event[3])) + ' → ' + Std.string(event[4]);
        if (def.engineName == 'Play Animation') return Std.string(event[4]) + ' → ' + Std.string(event[3]);
        return 'V1=' + Std.string(event[3]) + '  V2=' + Std.string(event[4]);
    }

    static function formatTime(value:Dynamic):String
    {
        var ms:Float = Std.parseFloat(Std.string(value));
        if (Math.isNaN(ms)) ms = 0;
        var minutes = Std.int(ms / 60000);
        var seconds = (ms - minutes * 60000) / 1000;
        var secText = seconds < 10 ? '0' + StringTools.lpad(Std.string(Math.floor(seconds * 1000) / 1000), '0', 5) : Std.string(Math.floor(seconds * 1000) / 1000);
        return StringTools.lpad(Std.string(minutes), '0', 2) + ':' + secText;
    }

    public function checkpoint():Void
    {
        var snapshot = Json.stringify({song: chart.mobileGetSong()});
        if (undoStack.length == 0 || undoStack[undoStack.length - 1] != snapshot)
        {
            undoStack.push(snapshot);
            if (undoStack.length > MAX_HISTORY) undoStack.shift();
        }
        redoStack = [];
    }

    public function restoreUndo():Void
    {
        if (undoStack.length <= 1) return;
        var current = undoStack.pop();
        redoStack.push(current);
        restoreSnapshot(undoStack[undoStack.length - 1]);
        statusMessage('Undo');
    }

    public function restoreRedo():Void
    {
        if (redoStack.length == 0) return;
        var snapshot = redoStack.pop();
        undoStack.push(snapshot);
        restoreSnapshot(snapshot);
        statusMessage('Redo');
    }

    function restoreSnapshot(snapshot:String):Void
    {
        var parsed:Dynamic = Json.parse(snapshot);
        chart.mobileReplaceSong(cast Reflect.field(parsed, 'song'));
        if (currentPanel != 'classic') showPanel(currentPanel);
    }

    public function saveDirect():Void
    {
        applyPendingTextFields();
        var song = chart.mobileGetSong();
        var data = Json.stringify({song: song}, '\t');
        MobileEditorFileSystem.ensureProject();
        var path = MobileEditorFileSystem.songPath(song.song);
        var ok = MobileEditorFileSystem.safeWriteJson(path, data);
        MobileEditorFileSystem.saveAutosave('chart', Paths.formatToSongPath(song.song), data);
        statusMessage(ok ? 'SALVO DIRETO NO MOD' : 'ERRO AO SALVAR');
        FlxG.sound.play(Paths.sound(ok ? 'confirmMenu' : 'cancelMenu'));
    }

    function applyPendingTextFields():Void
    {
        if (songNameInput != null && bpmInput != null && speedInput != null) applySongFields();
    }

    public function openEventEditor():Void
    {
        var selected = chart.mobileGetSelectedNote();
        var existing:Array<Dynamic> = null;
        if (selected != null && selected.length >= 5 && Std.int(selected[1]) < 0) existing = selected;
        FlxG.state.openSubState(new MobileEventEditorSubState(this, existing));
    }

    public function addEvent(name:String, value1:String, value2:String):Void
    {
        checkpoint();
        chart.mobileAddEvent(name, value1, value2);
        showPanel('events');
    }

    public function updateEvent(existing:Array<Dynamic>, name:String, value1:String, value2:String):Void
    {
        checkpoint();
        chart.mobileUpdateEvent(existing, name, value1, value2);
        showPanel('events');
    }

    public function animationsForSlot(slot:String):Array<String>
    {
        var song = chart.mobileGetSong();
        var id = switch (MobileEventRegistry.normalizeSlot(slot))
        {
            case 'bf': song.player1;
            case 'gf': song.player3;
            default: song.player2;
        };
        return readAnimations(id);
    }

    function readAnimations(character:String):Array<String>
    {
        var out:Array<String> = [];
        #if sys
        var candidates = [
            MobileEditorFileSystem.currentModRoot() + 'characters/' + character + '.json',
            'assets/characters/' + character + '.json'
        ];
        for (path in candidates)
        {
            if (!FileSystem.exists(path)) continue;
            try
            {
                var data:Dynamic = Json.parse(File.getContent(path));
                var animations:Array<Dynamic> = cast Reflect.field(data, 'animations');
                if (animations != null)
                    for (anim in animations)
                    {
                        var name = Std.string(Reflect.field(anim, 'anim'));
                        if (name != null && name.length > 0 && out.indexOf(name) == -1) out.push(name);
                    }
                if (out.length > 0) break;
            }
            catch (e:Dynamic) trace(e);
        }
        #end
        return out;
    }

    public function previewCamera(x:Float, y:Float):Void
    {
        statusMessage('Preview câmera: X=' + x + ' Y=' + y);
        FlxG.camera.scroll.set(x - FlxG.width * 0.5, y - FlxG.height * 0.5);
    }

    public function previewCharacter(slot:String, character:String):Void
    {
        statusMessage('Preview: ' + MobileEventRegistry.normalizeSlot(slot) + ' → ' + character);
    }

    public function previewAnimation(slot:String, animation:String):Void
    {
        statusMessage('Preview animação: ' + MobileEventRegistry.normalizeSlot(slot) + ' / ' + animation);
    }

    function statusMessage(text:String):Void
    {
        if (status != null) status.text = text;
    }
}
