package editors.mobile;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/** Large touch target used by the mobile editor layer. */
class MobileButton extends FlxSpriteGroup
{
    public var background(default, null):FlxSprite;
    public var label(default, null):FlxText;
    public var enabled:Bool = true;
    public var onPress:Void->Void;

    var buttonWidth:Float;
    var buttonHeight:Float;

    public function new(x:Float, y:Float, width:Float, height:Float, text:String, ?callback:Void->Void)
    {
        super(x, y);
        buttonWidth = width;
        buttonHeight = height;
        onPress = callback;

        background = new FlxSprite().makeGraphic(Std.int(width), Std.int(height), 0xFF2D3340);
        background.scrollFactor.set();
        add(background);

        label = new FlxText(8, 0, Std.int(width - 16), text, 22);
        label.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, CENTER);
        label.y = (height - label.height) * 0.5;
        label.scrollFactor.set();
        add(label);
        scrollFactor.set();
    }

    public function setText(text:String):Void
    {
        label.text = text;
        label.y = (buttonHeight - label.height) * 0.5;
    }

    public function setSelected(selected:Bool):Void
    {
        background.color = selected ? 0xFF5967A8 : 0xFFFFFFFF;
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        if (!enabled || onPress == null) return;

        var pressed:Bool = false;
        #if mobile
        for (touch in FlxG.touches.list)
        {
            if (touch.justReleased && containsPoint(touch.screenX, touch.screenY))
            {
                pressed = true;
                break;
            }
        }
        #end

        if (!pressed && FlxG.mouse.justReleased && containsPoint(FlxG.mouse.screenX, FlxG.mouse.screenY))
            pressed = true;

        if (pressed) onPress();
    }

    inline function containsPoint(px:Float, py:Float):Bool
    {
        return px >= x && px <= x + buttonWidth && py >= y && py <= y + buttonHeight;
    }
}
