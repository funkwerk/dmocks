module dmocks.interval;

import dmocks.util;
import std.conv;
import std.exception;

package:

struct Interval 
{
    bool Valid () { return Min <= Max; }

    private int _min;
    private int _max;

    @property int Min()
    {
        return _min;
    }

    @property int Max()
    {
        return _max;
    }

    string toString () const
    {
        if (_min == _max)
            return std.conv.to!string(_min);
        return std.conv.to!string(_min) ~ ".." ~ std.conv.to!string(_max);
    }

    this (int min, int max) 
    {
        this._min = min;
        this._max = max;
        enforceValid();
    }

    void enforceValid()
    {
        enforce!MocksSetupException(Valid, "Interval: invalid interval range: "~ toString());
    }
}

unittest
{
    Interval t = Interval(1, 2);
    assert (to!string(t) == "1..2");
}

unittest
{
    Interval t = Interval(1, 1);
    assert (to!string(t) == "1");
}
