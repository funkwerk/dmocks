module dmocks.action;

import dmocks.dynamic;
import dmocks.util;
import std.meta : AliasSeq;
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
        T value = void;

        this(T value, bool pass, ActionStatus status = ActionStatus.Success)
        {
            this.value = value;
            this.pass = pass;
            this.status = status;
        }
    }

    this(bool pass, ActionStatus status = ActionStatus.Success)
    {
        this.pass = pass;
        this.status = status;
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

        alias Rope = ReturnOrPass!TReturn;

        if (self.passThrough)
        {
            return Rope(true);
        }
        if (self.toThrow)
        {
            throw self.toThrow;
        }
        static if (is (TReturn == void))
        {
            if (self.action is null)
            {
                return Rope(false);
            }
            debugLog("action found, type: %s", self.action.type);

            if (self.action.type == typeid(void delegate(ArgTypes)))
            {
                self.action.get!(void delegate(ArgTypes))()(args);
                return Rope(false);
            }
            else
            {
                return Rope(false, ActionStatus.FailBadAction);
            }
        }
        else
        {
            if (self.returnValue !is null)
            {
                return Rope(self.returnValue.get!TReturn, false);
            }
            else if (self.action !is null)
            {
                debugLog("action found, type: %s", self.action.type);
                if (self.action.type == typeid(TReturn delegate(ArgTypes)))
                {
                    return Rope(self.action.get!(TReturn delegate(ArgTypes))()(args), false);
                }
                else
                {
                    return Rope(false, ActionStatus.FailBadAction);
                }
            }
            return Rope(false);
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
