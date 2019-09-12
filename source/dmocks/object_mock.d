module dmocks.object_mock;

import core.vararg;
import dmocks.method_mock;
import dmocks.model;
import dmocks.repository;
import std.traits;

class Mocked (T) : T 
{
    static if(__traits(hasMember, T,"__ctor"))
        this(ARGS...)(ARGS args)
        {
            super(args);
        }

    package MockRepository _owner;
    package MockId mockId___ = new MockId;
    mixin ((Body!(T, true)));
}

class MockedFinal(T)
{
    package T mocked___;
    package MockRepository _owner;
    package MockId mockId___ = new MockId;

    package this(T t)
    {
        mocked___ = t;
    }

    auto ref opDispatch(string name, Args...)(auto ref Args params)
    {
        //TODO: how do i get an alias to a template overloaded on args?
        mixin("alias this.mocked___."~name~"!Args METHOD;");
        auto del = delegate ReturnType!(FunctionTypeOf!METHOD) (Args args, TypeInfo[] varArgsList, void* varArgsPtr){ mixin(BuildForwardCall!(name ~ "!Args", false)()); };
        return mockMethodCall!(METHOD, name, typeof(mocked___))(this, this._owner, del, null, null, params);
    }

    mixin ((Body!(T, false)));
}

unittest 
{
    class A
    {
        void asd(T)(int a)
        {
        }
    }

    class Overloads
    {
        private int _foo;

        T foot(T)()
        {
            static if (is(T == int))
            {
                return _foo;
            }
            else
                return T.init;
        }

        void foot(T)(T i)
        {
            static if (is(T == int))
            {
                _foo = i;
            }
        }
    }
    auto f = new MockedFinal!A(new A);
    static assert(__traits(compiles, f.opDispatch!("asd")(1)));

    //auto p = new MockedFinal!Overloads(new Overloads);
    //p.opDispatch!("foot")(5);
}

struct MockedStruct(T)
{
    package T mocked___;
    package MockRepository _owner;
    package MockId mockId___;

    package this(T t)
    {
        mockId___ = new MockId;
        mocked___ = t;
    }

    auto ref opDispatch(string name, Args...)(auto ref Args params)
    {
        //TODO: how do i get an alias to a template overloaded on args?
        mixin("alias this.mocked___."~name~"!Args METHOD;");
        auto del = delegate ReturnType!(FunctionTypeOf!METHOD) (Args args, TypeInfo[] varArgsList, void* varArgsPtr){ mixin(BuildForwardCall!(name ~ "!Args", false)()); };
        return mockMethodCall!(METHOD, name, typeof(mocked___))(this, this._owner, del, null, null, params);
    }

    mixin ((Body!(T, false)));
}

auto ref mockMethodCall(alias self, string name, T, OBJ, CALLER, FORWARD, Args...)(OBJ obj, CALLER _owner, FORWARD forwardCall, TypeInfo[] varArgsList, void* varArgsPtr, auto ref Args params)
{
    if (_owner is null) 
    {
        assert(false, "owner cannot be null! Contact the stupid mocks developer.");
    }
    auto getRope()
    {
        // CAST CHEATS here - can't operate on const/shared refs without cheating on typesystem.
        // this makes these calls threadunsafe
        // because of fullyQualifiedName bug we need to pass name to the function
        return (cast()_owner).MethodCall!(self, ParameterTypeTuple!self)
            (cast(MockId)(obj.mockId___), __traits(identifier, T) ~ "." ~ name, params);
    }
    auto rope = ({
        static if (functionAttributes!(FunctionTypeOf!(self)) & FunctionAttribute.nothrow_)
        {
            try {
                return getRope();
            }
            catch (Exception ex)
            {
                assert(false, "Throwing in a mock of a nothrow method!");
            }
        }
        else
        {
            return getRope();
        }
    })();
    if (rope.pass)
    {
        return forwardCall(params, varArgsList, varArgsPtr);
    }
    else
    {
        static if (!is (ReturnType!(FunctionTypeOf!(self)) == void))
        {
            return rope.value;
        }
    }
}

template Body (T, bool INHERITANCE) 
{
    enum Body = BodyPart!(T, 0);

    template BodyPart (T, int i)
    {
        static if (i < __traits(allMembers, T).length) 
        {
            //pragma(msg, __traits(allMembers, T)[i]);
            enum BodyPart = Methods!(T, INHERITANCE, __traits(allMembers, T)[i]) ~ BodyPart!(T, i + 1);
        }
        else 
        {
            enum BodyPart = ``;
        }
    }
}
