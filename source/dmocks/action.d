module dmocks.action;

import dmocks.dynamic;
import dmocks.util;
import std.traits;

package:

enum ActionStatus
{
    Success,
    FailBadAction,
}

struct ReturnOrPass(T)
{
    static if (!is(T == void))
    {
        static if (is(typeof({ Unqual!T value; })))
        {
            Unqual!T value;
        }
        else
        {
            auto value = Unqual!T.init;
        }
    }

    bool pass;
    ActionStatus status = ActionStatus.Success;
}

struct Actor 
{
    Action self;

    ReturnOrPass!(TReturn) act (TReturn, ArgTypes...) (ArgTypes args)
    {
        debugLog("Actor:act");

        ReturnOrPass!(TReturn) rope;
        if (self.passThrough)
        {
            rope.pass = true;
            return rope;
        }
        if (self.toThrow)
        {
            throw self.toThrow;
        }
        static if (is (TReturn == void))
        {
            if (self.action !is null)
            {
                debugLog("action found, type: %s", self.action.type);
                
                if (self.action.type == typeid(void delegate(ArgTypes)))
                {
                    self.action.get!(void delegate(ArgTypes))()(args);
                }
                else
                {
                    rope.status = ActionStatus.FailBadAction;
                }
            }
        }
        else
        {
            if (self.returnValue !is null)
            {
                rope.value = self.returnValue.get!(Unqual!TReturn);
            }
            else if (self.action !is null)
            {
                debugLog("action found, type: %s", self.action.type);
                if (self.action.type == typeid(TReturn delegate(ArgTypes)))
                {
                    rope.value = self.action.get!(Unqual!TReturn delegate(ArgTypes))()(args);
                }
                else
                {
                    rope.status = ActionStatus.FailBadAction;
                }
            }
        }

        return rope;
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
            dynamic.canConvertTo(this._returnType),
            format!"Cannot set return value to '%s': expected '%s'"(dynamic.type, this._returnType));

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

@("action accepts null returnValue for array")
unittest
{
    Action act = new Action(typeid(string));

    act.returnValue = dynamic(null);
    assert(act.returnValue.get!string is null);
}

@("action accepts null returnValue for pointer")
unittest
{
    Action act = new Action(typeid(int*));

    act.returnValue = dynamic(null);
    assert(act.returnValue.get!(int*) is null);
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
