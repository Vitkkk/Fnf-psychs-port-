package editors.mobile;

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
