package editors.mobile;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.ui.FlxUIInputText;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;

using StringTools;

/** Visual event editor that converts friendly fields back to Psych 0.4.2 Value 1 / Value 2. */
class MobileEventEditorSubState extends FlxSubState
{
    var bridge:MobileChartBridge;
    var existing:Array<Dynamic>;
    var definition:MobileEventDefinition;
    var values:Map<String, String> = new Map();
    var inputs:Map<String, FlxUIInputText> = new Map();
    var customMode:Bool = false;
    var customEvent:FlxUIInputText;
    var customV1:FlxUIInputText;
    var customV2:FlxUIInputText;

    public function new(bridge:MobileChartBridge, ?existing:Array<Dynamic>)
    {
        super(0xE80C1017);
        this.bridge = bridge;
        this.existing = existing;
    }

    override function create():Void
    {
        super.create();
        if (existing != null && existing.length >= 5)
        {
            definition = MobileEventRegistry.findByEngineName(Std.string(existing[2]));
            if (definition == null)
            {
                customMode = true;
                drawCustom(Std.string(existing[2]), Std.string(existing[3]), Std.string(existing[4]));
            }
            else
            {
                loadDecoded(definition.decode(Std.string(existing[3]), Std.string(existing[4])));
                drawDefinition();
            }
        }
        else drawPicker();
    }

    function baseTitle(text:String):Void
    {
        var title = new FlxText(24, 18, FlxG.width - 48, text, 30);
        title.setFormat(Paths.font('vcr.ttf'), 30, FlxColor.WHITE, CENTER);
        add(title);
        add(new MobileButton(24, 14, 140, 48, '< CANCELAR', function() close()));
    }

    function drawPicker():Void
    {
        baseTitle('ADICIONAR EVENTO');
        var defs = MobileEventRegistry.all();
        for (i in 0...defs.length)
        {
            var d = defs[i];
            var col = i % 2;
            var row = Std.int(i / 2);
            var w = (FlxG.width - 92) / 2;
            var x = 30 + col * (w + 32);
            var y = 100 + row * 104;
            add(new MobileButton(x, y, w, 84, d.displayName + '\n' + d.category, function() {
                definition = d;
                for (field in definition.fields) values.set(field.id, field.defaultValue);
                clearAndDrawDefinition();
            }));
        }
        var y = 100 + Std.int(Math.ceil(defs.length / 2)) * 104;
        add(new MobileButton(30, y, FlxG.width - 60, 72, 'CUSTOM EVENT  •  Value 1 / Value 2', function() {
            clearStateObjects();
            customMode = true;
            drawCustom('', '', '');
        }));
    }

    function clearStateObjects():Void
    {
        var copy = members.copy();
        for (member in copy)
        {
            if (member != null)
            {
                remove(member, true);
                member.destroy();
            }
        }
        inputs = new Map();
    }

    function clearAndDrawDefinition():Void
    {
        clearStateObjects();
        drawDefinition();
    }

    function loadDecoded(decoded:Dynamic):Void
    {
        for (field in definition.fields)
        {
            var v = Reflect.field(decoded, field.id);
            values.set(field.id, v == null ? field.defaultValue : Std.string(v));
        }
    }

    function drawDefinition():Void
    {
        baseTitle(definition.displayName.toUpperCase());
        var desc = new FlxText(46, 76, FlxG.width - 92, definition.description, 17);
        desc.setFormat(Paths.font('vcr.ttf'), 17, 0xFFB9C1D0, CENTER);
        add(desc);

        var y:Float = 142;
        for (field in definition.fields)
        {
            addField(field, y);
            y += 82;
        }

        if (definition.previewKind != null && definition.previewKind.length > 0)
            add(new MobileButton(44, FlxG.height - 142, 250, 54, '▶ TESTAR PREVIEW', preview));

        add(new MobileButton(FlxG.width - 272, FlxG.height - 142, 228, 54, existing == null ? 'ADICIONAR EVENTO' : 'SALVAR EVENTO', saveDefinition));
        var hint = new FlxText(44, FlxG.height - 72, FlxG.width - 88, 'Compatibilidade interna: ' + definition.engineName + ' → Value 1 / Value 2', 16);
        hint.setFormat(Paths.font('vcr.ttf'), 16, 0xFF8E98AA, CENTER);
        add(hint);
    }

    function addField(field:MobileEventField, y:Float):Void
    {
        var label = new FlxText(44, y, 270, field.label, 19);
        label.setFormat(Paths.font('vcr.ttf'), 19, FlxColor.WHITE, LEFT);
        add(label);
        var value = values.exists(field.id) ? values.get(field.id) : field.defaultValue;

        switch (field.type)
        {
            case 'slot':
                var button:MobileButton = null;
                button = new MobileButton(320, y - 10, FlxG.width - 364, 56, slotLabel(value), function() {
                    var slots = ['bf', 'dad', 'gf'];
                    var now = values.get(field.id);
                    var idx = slots.indexOf(now);
                    values.set(field.id, slots[(idx + 1 + slots.length) % slots.length]);
                    button.setText(slotLabel(values.get(field.id)));
                    refreshAnimationIfNeeded();
                });
                add(button);

            case 'choice':
                var opts = field.options == null ? [] : field.options;
                var button:MobileButton = null;
                button = new MobileButton(320, y - 10, FlxG.width - 364, 56, value, function() {
                    if (opts.length == 0) return;
                    var idx = opts.indexOf(values.get(field.id));
                    idx = (idx + 1 + opts.length) % opts.length;
                    values.set(field.id, opts[idx]);
                    button.setText(opts[idx]);
                });
                add(button);

            case 'character':
                var button:MobileButton = null;
                button = new MobileButton(320, y - 10, FlxG.width - 364, 56, value + '  • ALTERAR', function() {
                    openSubState(new MobileCharacterPickerSubState(function(selected:String) {
                        values.set(field.id, selected);
                        button.setText(selected + '  • ALTERAR');
                    }));
                });
                add(button);

            case 'animation':
                var button:MobileButton = null;
                button = new MobileButton(320, y - 10, FlxG.width - 364, 56, value + ' ▼', function() {
                    var animations = bridge.animationsForSlot(values.get('slot'));
                    if (animations.length == 0) return;
                    var idx = animations.indexOf(values.get(field.id));
                    idx = (idx + 1 + animations.length) % animations.length;
                    values.set(field.id, animations[idx]);
                    button.setText(animations[idx] + ' ▼');
                });
                add(button);

            default:
                var input = new FlxUIInputText(320, y - 2, FlxG.width - 364, value, 22);
                input.focusGained = function() FlxG.stage.window.textInputEnabled = true;
                input.focusLost = function() {
                    FlxG.stage.window.textInputEnabled = false;
                    values.set(field.id, input.text.trim());
                };
                inputs.set(field.id, input);
                add(input);
        }
    }

    function refreshAnimationIfNeeded():Void
    {
        if (!values.exists('animation')) return;
        var animations = bridge.animationsForSlot(values.get('slot'));
        if (animations.length > 0 && animations.indexOf(values.get('animation')) == -1)
            values.set('animation', animations[0]);
    }

    function syncInputs():Void
    {
        for (id in inputs.keys()) values.set(id, inputs.get(id).text.trim());
    }

    function saveDefinition():Void
    {
        syncInputs();
        var pair = definition.encode(valuesToObject());
        if (existing == null) bridge.addEvent(definition.engineName, pair[0], pair[1]);
        else bridge.updateEvent(existing, definition.engineName, pair[0], pair[1]);
        close();
    }

    function valuesToObject():Dynamic
    {
        var obj:Dynamic = {};
        for (key in values.keys()) Reflect.setField(obj, key, values.get(key));
        return obj;
    }

    function drawCustom(name:String, v1:String, v2:String):Void
    {
        baseTitle('CUSTOM EVENT');
        customEvent = addInput('Evento', name, 132);
        customV1 = addInput('Value 1', v1, 242);
        customV2 = addInput('Value 2', v2, 352);
        add(new MobileButton(FlxG.width - 272, FlxG.height - 110, 228, 56, existing == null ? 'ADICIONAR EVENTO' : 'SALVAR EVENTO', function() {
            if (existing == null) bridge.addEvent(customEvent.text.trim(), customV1.text, customV2.text);
            else bridge.updateEvent(existing, customEvent.text.trim(), customV1.text, customV2.text);
            close();
        }));
    }

    function addInput(labelText:String, value:String, y:Float):FlxUIInputText
    {
        var label = new FlxText(44, y, FlxG.width - 88, labelText, 20);
        label.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, LEFT);
        add(label);
        var input = new FlxUIInputText(44, y + 34, FlxG.width - 88, value, 22);
        input.focusGained = function() FlxG.stage.window.textInputEnabled = true;
        input.focusLost = function() FlxG.stage.window.textInputEnabled = false;
        add(input);
        return input;
    }

    function preview():Void
    {
        syncInputs();
        switch (definition.previewKind)
        {
            case 'flash':
                var hex = values.get('color');
                if (hex == null) hex = 'FFFFFF';
                hex = hex.replace('#', '').replace('0x', '');
                var rgb:Null<Int> = Std.parseInt('0x' + hex);
                if (rgb == null) rgb = 0xFFFFFF;
                var opacity = parse(values.get('opacity'), 1);
                var duration = parse(values.get('duration'), 0.5);
                var alpha = Std.int(FlxMath.bound(opacity, 0, 1) * 255);
                var color:Int = (alpha << 24) | rgb;
                FlxG.camera.flash(color, duration);
            case 'shake':
                FlxG.camera.shake(parse(values.get('gameIntensity'), 0.03), parse(values.get('gameDuration'), 0.5));
            case 'camera':
                bridge.previewCamera(parse(values.get('x'), 0), parse(values.get('y'), 0));
            case 'character':
                bridge.previewCharacter(values.get('slot'), values.get('character'));
            case 'animation':
                bridge.previewAnimation(values.get('slot'), values.get('animation'));
        }
    }

    static function parse(value:String, fallback:Float):Float
    {
        var out = Std.parseFloat(value);
        return Math.isNaN(out) ? fallback : out;
    }

    static function slotLabel(value:String):String
    {
        return switch (MobileEventRegistry.normalizeSlot(value))
        {
            case 'bf': 'PLAYER / BF';
            case 'gf': 'GF';
            default: 'OPPONENT / DAD';
        }
    }
}
