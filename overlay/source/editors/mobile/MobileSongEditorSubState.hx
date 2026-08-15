package editors.mobile;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.ui.FlxUIInputText;
import flixel.text.FlxText;
import flixel.util.FlxColor;

using StringTools;

/** Touch-friendly song card editor used by MobileWeekEditorState. */
class MobileSongEditorSubState extends FlxSubState
{
    public var onSave:MobileWeekSongEdit->Void;

    var displayInput:FlxUIInputText;
    var internalInput:FlxUIInputText;
    var customDifficulty:FlxUIInputText;
    var difficulties:Array<String>;
    var diffButtons:Array<MobileButton> = [];
    var info:FlxText;

    public function new(?existing:MobileWeekSongEdit, callback:MobileWeekSongEdit->Void)
    {
        super(0xDD0E1118);
        onSave = callback;
        if (existing == null)
            existing = {displayName: 'Nova Música', internalName: 'nova-musica', difficulties: ['Easy', 'Normal', 'Hard']};
        difficulties = existing.difficulties.copy();
        _initial = existing;
    }

    var _initial:MobileWeekSongEdit;

    override function create():Void
    {
        super.create();
        var title = new FlxText(32, 24, FlxG.width - 64, 'MÚSICA DA WEEK', 30);
        title.setFormat(Paths.font('vcr.ttf'), 30, FlxColor.WHITE, CENTER);
        add(title);

        addLabel('Nome exibido', 105);
        displayInput = new FlxUIInputText(40, 138, FlxG.width - 80, _initial.displayName, 22);
        setupInput(displayInput);
        add(displayInput);

        addLabel('Nome interno', 205);
        internalInput = new FlxUIInputText(40, 238, FlxG.width - 80, _initial.internalName, 22);
        setupInput(internalInput);
        add(internalInput);

        addLabel('Dificuldades', 305);
        rebuildDifficultyButtons();

        customDifficulty = new FlxUIInputText(40, 452, FlxG.width - 270, '', 20);
        setupInput(customDifficulty);
        add(customDifficulty);
        var addDiff = new MobileButton(FlxG.width - 215, 442, 175, 50, '+ DIFICULDADE', function() {
            var value = customDifficulty.text.trim();
            if (value.length > 0 && !containsDifficulty(value))
            {
                difficulties.push(value);
                customDifficulty.text = '';
                rebuildDifficultyButtons();
            }
        });
        add(addDiff);

        info = new FlxText(40, 505, FlxG.width - 80, 'Toque numa dificuldade para ativar/desativar. Normal é mantida por padrão ao salvar charts sem sufixo.', 17);
        info.setFormat(Paths.font('vcr.ttf'), 17, 0xFFB9C1D0, LEFT);
        add(info);

        add(new MobileButton(40, FlxG.height - 78, 180, 56, 'CANCELAR', function() close()));
        add(new MobileButton(FlxG.width - 220, FlxG.height - 78, 180, 56, 'SALVAR', saveAndClose));
    }

    function setupInput(input:FlxUIInputText):Void
    {
        input.focusGained = function() FlxG.stage.window.textInputEnabled = true;
        input.focusLost = function() FlxG.stage.window.textInputEnabled = false;
    }

    function addLabel(text:String, y:Float):Void
    {
        var label = new FlxText(40, y, FlxG.width - 80, text, 20);
        label.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, LEFT);
        add(label);
    }

    function rebuildDifficultyButtons():Void
    {
        for (button in diffButtons)
        {
            remove(button, true);
            button.destroy();
        }
        diffButtons = [];

        var presets = ['Easy', 'Normal', 'Hard'];
        for (i in 0...presets.length)
        {
            var name = presets[i];
            var button:MobileButton = null;
            button = new MobileButton(40 + i * 205, 344, 185, 54, name, function() {
                toggleDifficulty(name);
                button.setSelected(containsDifficulty(name));
            });
            button.setSelected(containsDifficulty(name));
            diffButtons.push(button);
            add(button);
        }

        var custom:Array<String> = [];
        for (d in difficulties)
            if (d.toLowerCase() != 'easy' && d.toLowerCase() != 'normal' && d.toLowerCase() != 'hard') custom.push(d);

        for (i in 0...custom.length)
        {
            if (i >= 3) break;
            var name = custom[i];
            var button = new MobileButton(40 + i * 205, 406, 185, 38, name + '  ×', function() {
                removeDifficulty(name);
                rebuildDifficultyButtons();
            });
            diffButtons.push(button);
            add(button);
        }
    }

    function toggleDifficulty(name:String):Void
    {
        if (containsDifficulty(name)) removeDifficulty(name); else difficulties.push(name);
    }

    function containsDifficulty(name:String):Bool
    {
        for (d in difficulties) if (d.toLowerCase() == name.toLowerCase()) return true;
        return false;
    }

    function removeDifficulty(name:String):Void
    {
        var i = difficulties.length - 1;
        while (i >= 0)
        {
            if (difficulties[i].toLowerCase() == name.toLowerCase()) difficulties.splice(i, 1);
            i--;
        }
    }

    function saveAndClose():Void
    {
        var internal = MobileEditorFileSystem.sanitizeId(internalInput.text);
        if (difficulties.length == 0) difficulties.push('Normal');
        if (onSave != null)
            onSave({displayName: displayInput.text.trim(), internalName: internal, difficulties: difficulties.copy()});
        close();
    }
}
