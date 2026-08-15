package editors.mobile;

typedef MobileEventField =
{
    var id:String;
    var label:String;
    var type:String;
    var defaultValue:String;
    @:optional var options:Array<String>;
    @:optional var min:Float;
    @:optional var max:Float;
}

class MobileEventDefinition
{
    public var displayName:String;
    public var engineName:String;
    public var category:String;
    public var description:String;
    public var fields:Array<MobileEventField>;
    public var previewKind:String;
    public var decode:String->String->Dynamic;
    public var encode:Dynamic->Array<String>;

    public function new(displayName:String, engineName:String, category:String, description:String,
        fields:Array<MobileEventField>, previewKind:String,
        decode:String->String->Dynamic, encode:Dynamic->Array<String>)
    {
        this.displayName = displayName;
        this.engineName = engineName;
        this.category = category;
        this.description = description;
        this.fields = fields;
        this.previewKind = previewKind;
        this.decode = decode;
        this.encode = encode;
    }
}

/** Registry-backed event architecture. Adding an event does not require touching ChartingState. */
class MobileEventRegistry
{
    static var definitions:Array<MobileEventDefinition>;

    public static function all():Array<MobileEventDefinition>
    {
        if (definitions == null) build();
        return definitions.copy();
    }

    public static function findByEngineName(name:String):Null<MobileEventDefinition>
    {
        if (definitions == null) build();
        for (d in definitions) if (d.engineName.toLowerCase() == name.toLowerCase()) return d;
        return null;
    }

    static function build():Void
    {
        definitions = [];

        definitions.push(new MobileEventDefinition(
            'Switch Character', 'Change Character', 'Personagem',
            'Troca visualmente Player, Opponent ou GF por outro personagem instalado.',
            [
                {id:'slot', label:'Slot', type:'slot', defaultValue:'dad'},
                {id:'character', label:'Trocar para', type:'character', defaultValue:'pico'}
            ], 'character',
            function(v1:String, v2:String):Dynamic return {slot: normalizeSlot(v1), character: v2},
            function(v:Dynamic):Array<String> return [normalizeSlot(Std.string(Reflect.field(v, 'slot'))), Std.string(Reflect.field(v, 'character'))]
        ));

        definitions.push(new MobileEventDefinition(
            'Screen Flash', 'Super Flash', 'Tela',
            'Flash de tela. Value 1 continua sendo a duração original; Value 2 guarda cor/opacidade/ease para este fork.',
            [
                {id:'color', label:'Cor HEX', type:'color', defaultValue:'FFFFFF'},
                {id:'opacity', label:'Opacidade', type:'number', defaultValue:'1'},
                {id:'duration', label:'Duração (s)', type:'number', defaultValue:'0.5'},
                {id:'ease', label:'Ease', type:'choice', defaultValue:'linear', options:['linear','quadIn','quadOut','quadInOut']}
            ], 'flash',
            function(v1:String, v2:String):Dynamic {
                var bits = v2 == null ? [] : v2.split(',');
                return {
                    color: bits.length > 0 && bits[0].length > 0 ? bits[0] : 'FFFFFF',
                    opacity: bits.length > 1 ? bits[1] : '1',
                    duration: v1 == null || v1.length == 0 ? '0.5' : v1,
                    ease: bits.length > 2 ? bits[2] : 'linear'
                };
            },
            function(v:Dynamic):Array<String> return [
                Std.string(Reflect.field(v,'duration')),
                Std.string(Reflect.field(v,'color')) + ',' + Std.string(Reflect.field(v,'opacity')) + ',' + Std.string(Reflect.field(v,'ease'))
            ]
        ));

        definitions.push(new MobileEventDefinition(
            'Screen Shake', 'Screen Shake', 'Tela',
            'Configura separadamente shake da câmera de jogo e HUD.',
            [
                {id:'gameDuration', label:'Game duração', type:'number', defaultValue:'0.5'},
                {id:'gameIntensity', label:'Game intensidade', type:'number', defaultValue:'0.03'},
                {id:'hudDuration', label:'HUD duração', type:'number', defaultValue:'0'},
                {id:'hudIntensity', label:'HUD intensidade', type:'number', defaultValue:'0'}
            ], 'shake',
            function(v1:String, v2:String):Dynamic {
                var a = splitPair(v1, '0.5', '0.03');
                var b = splitPair(v2, '0', '0');
                return {gameDuration:a[0], gameIntensity:a[1], hudDuration:b[0], hudIntensity:b[1]};
            },
            function(v:Dynamic):Array<String> return [
                Std.string(Reflect.field(v,'gameDuration')) + ', ' + Std.string(Reflect.field(v,'gameIntensity')),
                Std.string(Reflect.field(v,'hudDuration')) + ', ' + Std.string(Reflect.field(v,'hudIntensity'))
            ]
        ));

        definitions.push(new MobileEventDefinition(
            'Camera Follow Position', 'Camera Follow Pos', 'Câmera',
            'Posiciona o follow point. Deixe X e Y vazios para retornar ao comportamento normal.',
            [
                {id:'x', label:'X', type:'number', defaultValue:''},
                {id:'y', label:'Y', type:'number', defaultValue:''}
            ], 'camera',
            function(v1:String, v2:String):Dynamic return {x:v1, y:v2},
            function(v:Dynamic):Array<String> return [Std.string(Reflect.field(v,'x')), Std.string(Reflect.field(v,'y'))]
        ));

        definitions.push(new MobileEventDefinition(
            'Play Animation', 'Play Animation', 'Personagem',
            'Escolhe o personagem e uma animação existente no JSON dele.',
            [
                {id:'slot', label:'Personagem', type:'slot', defaultValue:'bf'},
                {id:'animation', label:'Animação', type:'animation', defaultValue:'hey'}
            ], 'animation',
            function(v1:String, v2:String):Dynamic return {animation:v1, slot:normalizeSlot(v2)},
            function(v:Dynamic):Array<String> return [Std.string(Reflect.field(v,'animation')), normalizeSlot(Std.string(Reflect.field(v,'slot')))]
        ));
    }

    static function splitPair(value:String, fallbackA:String, fallbackB:String):Array<String>
    {
        if (value == null || value.length == 0) return [fallbackA, fallbackB];
        var bits = value.split(',');
        return [bits.length > 0 ? StringTools.trim(bits[0]) : fallbackA, bits.length > 1 ? StringTools.trim(bits[1]) : fallbackB];
    }

    public static function normalizeSlot(value:String):String
    {
        if (value == null) return 'dad';
        switch (value.toLowerCase())
        {
            case '0', 'bf', 'boyfriend', 'player': return 'bf';
            case '2', 'gf', 'girlfriend': return 'gf';
            default: return 'dad';
        }
    }
}
