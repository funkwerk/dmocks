module dmocks.action;

import dmocks.dynamic;
import dmocks.util;
import std.meta : AliasSeq;
import std.traits;
import std.typecons;

package:

struct ReturnOrPass(T)
{
    static if (!is(T == void))
    {
        T value = void;

        this(T value, Flag!"pass" pass)
        {
            this.value = value;
            this.pass = pass;
        }
    }

    this(Flag!"pass" pass)
    {
        this.pass = pass;
    }

    Flag!"pass" pass;
}

struct Actor 
{
    Action self;

    ReturnOrPass!(TReturn) act (TReturn, ArgTypes...) (ArgTypes args)
    {
        debugLog("Actor:act");

        alias Rope = ReturnOrPass!TReturn;

        if (self.passThrough)
        {
            return Rope(Yes.pass);
        }
        if (self.toThrow)
        {
            throw self.toThrow;
        }
        static if (is (TReturn == void))
        {
            if (self.action is null)
            {
                return Rope(No.pass);
            }
            debugLog("action found, type: %s", self.action.typename);

            if (self.action.type == typeid(void delegate(ArgTypes)))
            {
                self.action.get!(void delegate(ArgTypes))()(args);
                return Rope(No.pass);
            }
            else
            {
                import std.format : format;

                throw new Error(format!"cannot call action: type %s does not match argument type %s"
                    (self.action.typename, ArgTypes.stringof));
            }
        }
        else
        {
            if (self.returnValue !is null)
            {
                return Rope(self.returnValue.get!TReturn, No.pass);
            }
            else if (self.action !is null)
            {
                debugLog("action found, type: %s", self.action.typename);
                if (self.action.type == typeid(TReturn delegate(ArgTypes)))
                {
                    return Rope(self.action.get!(TReturn delegate(ArgTypes))()(args), No.pass);
                }
                else
                {
                    import std.format : format;

                    throw new Error(format!"cannot call action: type %s does not match argument type %s"
                        (self.action.typename, ArgTypes.stringof));
                }
            }
            return Rope(No.pass);
        }
    }
}

//TODO: make action parameters orthogonal or disallow certain combinations of them
class Action
{
    bool passThrough;

    private Dynamic _returnValue;

    Dynamic action;

    Exception toThrow;

    private TypeInfo _returnType;

    this(TypeInfo returnType)
    {
        this._returnType = returnType;
    }

    bool hasAction()
    {
        return (_returnType is typeid(void)) || (passThrough) ||
            (_returnValue !is null) || (action !is null) || (toThrow !is null);
    }

    Actor getActor()
    {
        Actor actor;

        actor.self = this;
        return actor;
    }

    @property Dynamic returnValue()
    {
        return this._returnValue;
    }

    @property void returnValue(Dynamic dynamic)
    {
        import std.exception : enforce;
        import std.format : format;

        enforce(
            dynamic.type == this._returnType || dynamic.canConvertTo(this._returnType),
            format!"Cannot set return value to '%s': expected '%s'"(dynamic.typename, this._returnType));

        this._returnValue = dynamic;
    }
}

@("action returnValue")
unittest
{
    Dynamic v = dynamic(5);
    Action act = new Action(typeid(int));
    assert (act.returnValue is null);
    act.returnValue = v;
    assert (act.returnValue == dynamic(5));
}

@("action throws on mismatching returnValue")
unittest
{
    import std.exception : assertThrown;

    Dynamic v = dynamic(5.0f);
    Action act = new Action(typeid(int));

    assert (act.returnValue is null);
    assertThrown!Exception (act.returnValue = v);
}

private interface ExampleInterface
{
}

static foreach (Type; AliasSeq!(string, int*, Object, ExampleInterface, void function(), void delegate()))
{
    @("action accepts null returnValue for " ~ Type.stringof)
    unittest
    {
        Action act = new Action(typeid(Type));

        act.returnValue = dynamic(null);
        assert(act.returnValue.get!Type is null);
    }
}

@("action action")
unittest
{
    Dynamic v = dynamic(5);
    Action act = new Action(typeid(int));
    assert (act.action is null);
    act.action = v;
    assert (act.action == v);
}

@("action exception")
unittest
{
    Exception ex = new Exception("boogah");
    Action act = new Action(typeid(int));
    assert (act.toThrow is null);
    act.toThrow = ex;
    assert (act.toThrow is ex);
}

@("action passthrough")
unittest
{
    Action act = new Action(typeid(int));
    act.passThrough = true;
    assert (act.passThrough);
    act.passThrough = false;
    assert (!act.passThrough);
}

@("action hasAction")
unittest
{
    Action act = new Action(typeid(int));
    act.returnValue = dynamic(5);
    assert(act.hasAction);
}
