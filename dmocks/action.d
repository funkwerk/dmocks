module dmocks.action;

import dmocks.util;
import dmocks.dynamic;
import std.traits;

package:

interface IAction
{
    bool passThrough ();

    void passThrough (bool value);

    Dynamic returnValue ();

    void returnValue (Dynamic value);

    void action (Dynamic value);

    Dynamic action ();

    Exception toThrow ();

    void toThrow (Exception value);

    bool hasAction ();
    
    Actor getActor ();
}

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
    IAction self;

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
                debugLog("action found, type: %s", self.action().type);
                
                if (self.action().type == typeid(void delegate(ArgTypes)))
                {
                    self.action().get!(void delegate(ArgTypes))()(args);
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
                rope.value = self.returnValue().get!(Unqual!TReturn);
            }
            else if (self.action !is null)
            {
                debugLog("action found, type: %s", self.action().type);
                if (self.action().type == typeid(TReturn delegate(ArgTypes)))
                {
                    rope.value = self.action().get!(Unqual!TReturn delegate(ArgTypes))()(args);
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
class Action : IAction
{
private
{
    bool _passThrough;
    Dynamic _returnValue;
    Dynamic _action;
    Exception _toThrow;
    TypeInfo _returnType;
}

    this(TypeInfo returnType)
    {
        this._returnType = returnType;
    }

    bool hasAction ()
    {
        return (_returnType is typeid(void)) || (_passThrough) || (_returnValue !is null) || (_action !is null) || (_toThrow !is null);
    }

    bool passThrough ()
    {
        return _passThrough;
    }

    void passThrough (bool value)
    {
        _passThrough = value;
    }

    Dynamic returnValue ()
    {
        return _returnValue;
    }

    void returnValue (Dynamic value)
    {
        _returnValue = value;
    }
    
    void action (Dynamic value)
    {
        _action = value;
    }

    Dynamic action ()
    {
        return _action;
    }

    Exception toThrow ()
    {
        return _toThrow;
    }

    void toThrow (Exception value)
    {
        _toThrow = value;
    }

    Actor getActor ()
    {
        Actor act;
        act.self = this;
        return act;
    }
}

@("action returnValue")
unittest
{
    Dynamic v = dynamic(5);
    Action act = new Action(typeid(int));
    assert (act.returnValue is null);
    act.returnValue = v;
    assert (act.returnValue() == dynamic(5));
}

@("action action")
unittest
{
    Dynamic v = dynamic(5);
    Action act = new Action(typeid(int));
    assert (act.action is null);
    act.action = v;
    assert (act.action() == v);
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
    assert (act.passThrough());
    act.passThrough = false;
    assert (!act.passThrough());
}

@("action hasAction")
unittest
{
    Action act = new Action(typeid(int));
    act.returnValue(dynamic(5));
    assert(act.hasAction);
}
