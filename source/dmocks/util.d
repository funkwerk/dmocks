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
            assert(false, "Could not write to error log");
        }
    }
}

template IsConcreteClass(T)
{
    static if ((is(T == class)) && (!__traits(isAbstractClass, T)))
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
    this(string file = __FILE__, size_t line = __LINE__)
    {
        super(typeof(this).stringof ~ "The requested operation is not valid.", file, line);
    }

    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(typeof(this).stringof ~ msg, file, line);
    }
}

/**
 * Thrown when an expectation was violated during unittest execution.
 */
public class ExpectationViolationError : Error
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/**
 * Thrown when an expectation violation was found during mocker verification.
 */
public class ExpectationViolationException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

public class MocksSetupException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(typeof(this).stringof ~ ": " ~ msg);
    }
}

public string yellow(string text)
{
    if (enableAnsiEscape)
    {
        return "\x1b[93m" ~ text ~ "\x1b[0m";
    }
    return text;
}

private bool enableAnsiEscape()
{
    version (Posix)
    {
        import core.sys.posix.unistd : isatty;

        return isatty(1 /* stdout */) ? true : false;
    }
    else
    {
        return false;
    }
}
