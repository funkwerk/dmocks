module dmocks.util;

public import dmocks.interval;
import std.conv;

string nullableToString(T)(T obj)
{
    if (obj is null)
        return "<null>";
    return obj.to!string;
}

void debugLog(T...)(lazy T args) @trusted nothrow
{
    debug (dmocks)
    {
        try
        {
            import std.stdio;
            writefln(args);
        }
        catch (Exception ex)
        {
            assert (false, "Could not write to error log");
        }
    }
}

template IsConcreteClass(T)
{
    static if ((is (T == class)) && (!__traits(isAbstractClass, T)))
    {
        const bool IsConcreteClass = true;
    }
    else 
    {
        const bool IsConcreteClass = false;
    }
}

class InvalidOperationException : Exception 
{
    this () { super(typeof(this).stringof ~ "The requested operation is not valid."); }
    this (string msg) { super(typeof(this).stringof ~ msg); }
}



public class ExpectationViolationException : Exception 
{
    this (string msg, string file = __FILE__, size_t line = __LINE__) 
    { 
        super(msg);
    }
}

public class MocksSetupException : Exception {
    this (string msg, string file = __FILE__, size_t line = __LINE__) {
        super (typeof(this).stringof ~ ": " ~ msg);
    }
}
