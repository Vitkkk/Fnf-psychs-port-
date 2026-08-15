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
