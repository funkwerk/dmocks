module dmocks.call;

import dmocks.arguments;
public import dmocks.dynamic;
public import dmocks.model;
import dmocks.qualifiers;
import std.array;

/++
+ This class represents a single method call on a mock object while in replay phase
+ All information about the call is stored here
+/
class Call
{
    MockId object;
    string name;
    string[] qualifiers;
    Dynamic[] arguments;

    override string toString()
    {
        string arguments = (arguments is null) ? "(<unknown>)" : arguments.formatArguments;
        return name ~ " "~ arguments ~ " " ~ qualifiers.join(" ");
    }
}

Call createCall(alias METHOD, ARGS...)(MockId object, string name, ARGS args)
{
    auto ret = new Call;
    ret.object = object;
    ret.name = name;
    ret.qualifiers = qualifiers!METHOD;
    ret.arguments = arguments(args);
    return ret;
}
