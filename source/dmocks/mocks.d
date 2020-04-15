module dmocks.mocks;

public import dmocks.dynamic;
import dmocks.factory;
public import dmocks.object_mock;
import dmocks.repository;
import dmocks.util;

/++
    A class through which one creates mock objects and manages expectations about calls to their methods.
 ++/
public class Mocker
{
    private MockRepository _repository;

    public
    {
        this()
        {
            _repository = new MockRepository();
        }

        /**
        * Start setting up expectations. Method calls on mock object will create (and record) new expectations. 
        * You can just call methods directly or use Mocker.expect/lastCall to customize expectations.
        */
        void record()
        {
            _repository.BackToRecord();
        }

        /** 
         * Stop setting up expectations. Any method calls after this point will
         * be matched against the expectations set up before calling replay and
         * expectations' actions will be executed.
         */
        void replay()
        {
            _repository.Replay();
        }

        /**
         * Verifies that certain expectation requirements were satisfied during replay phase.
         *
         * checkUnmatchedExpectations - Check to see if there are any expectations that haven't been
         * matched to a call. 
         *
         * checkUnexpectedCalls - Check to see if there are any calls that there were no
         * expectation set up for.
         *
         * Throws an ExpectationViolationError if those issues occur.
         */
        void verify(bool checkUnmatchedExpectations = true, bool checkUnexpectedCalls = true)
        {
            _repository.Verify(checkUnmatchedExpectations, checkUnexpectedCalls);
        }

        /**
         * By default, all expectations are unordered. If I want to require that
         * one call happen immediately after another, I call Mocker.ordered, make
         * those expectations, and call Mocker.unordered to avoid requiring a
         * particular order afterward.
         */
        void ordered()
        {
            _repository.Ordered(true);
        }

        void unordered()
        {
            _repository.Ordered(false);
        }

        /** 
         * Disables exceptions thrown on unexpected calls while in Replay phase
         * Unexpected methods called will return default value of their type
         *
         * Useful when using mocks as stubs or when you don't want exceptions 
         * to change flow of execution of your tests, for example when using nothrow functions
         *
         * Default: false
         */
        void allowUnexpectedCalls(bool allow)
        {
            _repository.AllowUnexpected(allow);
        }

        /** 
         * Creates a mock object for a given type.
         *
         * Calls matching expectations with passThrough enabled
         * will call equivalent methods of T object constructed with args.
         *
         * Type returned is binarily compatibile with given type
         * All virtual calls made to the object will be mocked
         * Final and template calls will not be mocked
         *
         * Use this type of mock to substitute interface/class objects
         */
        T mock(T, CONSTRUCTOR_ARGS...)(CONSTRUCTOR_ARGS args)
        {
            static assert(is(T == class) || is(T == interface),
                    "only classes and interfaces can be mocked using this type of mock");
            auto value = dmocks.factory.mock!(T)(_repository, args);
            static if (is(T == class)
                    && __traits(compiles, value.toString())
                    && __traits(compiles, value.opEquals(null)))
            {
                expectFallback(value.toString()).repeatAny.passThrough;
                expectFallback(value.opEquals(null)).ignoreArgs.repeatAny.passThrough;
            }
            return value;
        }

        /** 
         * Creates a mock object for a given type.
         *
         * Calls matching expectations with passThrough enabled
         * will call equivalent methods of T object constructed with args.
         *
         * Type of the mock is incompatibile with given type
         * Final, template and virtual methods will be mocked
         *
         * Use this type of mock to substitute template parameters
         */
        MockedFinal!T mockFinal(T, CONSTRUCTOR_ARGS...)(CONSTRUCTOR_ARGS args)
        {
            static assert(is(T == class) || is(T == interface),
                    "only classes and interfaces can be mocked using this type of mock");
            return dmocks.factory.mockFinal!(T)(_repository, args);
        }

        /** 
         * Creates a mock object for a given type.
         *
         * Calls matching expectations with passThrough enabled
         * will call equivalent methods of "to" object.
         *
         * Type of the mock is incompatibile with given type
         * Final, template and virtual methods will be mocked
         *
         * Use this type of mock to substitute template parameters
         */
        MockedFinal!T mockFinalPassTo(T)(T to)
        {
            static assert(is(T == class) || is(T == interface),
                    "only classes and interfaces can be mocked using this type of mock");
            return dmocks.factory.mockFinalPassTo!(T)(_repository, to);
        }

        /** 
         * Creates a mock object for a given type.
         *
         * Calls matching expectations with passThrough enabled
         * will call equivalent methods of T object constructed with args.
         *
         * Type of the mock is incompatibile with given type
         * Final, template and virtual methods will be mocked
         *
         * Use this type of mock to substitute template parameters
         */
        MockedStruct!T mockStruct(T, CONSTRUCTOR_ARGS...)(CONSTRUCTOR_ARGS args)
        {
            static assert(is(T == struct),
                    "only structs can be mocked using this type of mock");
            return dmocks.factory.mockStruct!(T)(_repository, args);
        }

        /** 
         * Creates a mock object for a given type.
         *
         * Calls matching expectations with passThrough enabled
         * will call equivalent methods of "to" object.
         *
         * Type of the mock is incompatibile with given type
         * Final, template and virtual methods will be mocked
         *
         * Use this type of mock to substitute template parameters
         */
        MockedStruct!T mockStructPassTo(T)(T to)
        {
            static assert(is(T == struct),
                    "only structs can be mocked using this type of mock");
            return dmocks.factory.mockStructPassTo!(T)(_repository, to);
        }

        /**
         * Record new expectation that will exactly match method called in methodCall argument
         *
         * Returns an object that allows you to set various properties of the expectation,
         * such as return value, number of repetitions or matching options.
         *
         * Examples:
         * ---
         * Mocker mocker = new Mocker;
         * Object obj = mocker.Mock!(Object);
         * mocker.expect(obj.toString).returns("hello?");
         * ---
         */
        ExpectationSetup expect(T)(lazy T methodCall)
        {
            auto pre = _repository.LastRecordedCallExpectation();
            methodCall();
            auto post = _repository.LastRecordedCallExpectation();
            if (pre is post)
                throw new InvalidOperationException("mocks.Mocker.expect: you did not call a method mocked by the mocker!");
            return lastCall();
        }

        private ExpectationSetup expectFallback(T)(lazy T methodCall)
        {
            _repository.RecordFallback(methodCall);
            return new ExpectationSetup(
                    _repository.LastRecordedFallbackCallExpectation(),
                    _repository.LastRecordedFallbackCall(),
            );
        }

        /**
         * Returns ExpectationSetup object for most recent call on a method of a mock object.
         *
         * This object allows you to set various properties of the expectation,
         * such as return value, number of repetitions or matching options.
         *
         * Examples:
         * ---
         * Mocker mocker = new Mocker;
         * Object obj = mocker.Mock!(Object);
         * obj.toString;
         * mocker.LastCall().returns("hello?");
         * ---
         */
        ExpectationSetup lastCall()
        {
            return new ExpectationSetup(_repository.LastRecordedCallExpectation(), _repository.LastRecordedCall());
        }

        /**
         * Set up a result for a method, but without any backend accounting for it.
         * Things where you want to allow this method to be called, but you aren't
         * currently testing for it.
         */
        ExpectationSetup allowing(T)(T ignored)
        {
            return lastCall().repeatAny;
        }

        /** Ditto */
        ExpectationSetup allowing(T = void)()
        {
            return lastCall().repeatAny();
        }

        /**
         * Do not require explicit return values for expectations. If no return
         * value is set, return the default value (null / 0 / nan, in most
         * cases). By default, if no return value, exception, delegate, or
         * passthrough option is set, an exception will be thrown.
         */
        void allowDefaults()
        {
            _repository.AllowDefaults(true);
        }
    }
}

/++
   An ExpectationSetup object allows you to set various properties of the expectation,
   such as: 
    - what action should be taken when method matching expectation is called
        - return value, action to call, exception to throw, etc

   Examples:
   ---
   Mocker mocker = new Mocker;
   Object obj = mocker.Mock!(Object);
   obj.toString;
   mocker.LastCall().returns("Are you still there?").repeat(1, 12);
   ---
++/
public class ExpectationSetup
{
    import dmocks.arguments;
    import dmocks.expectation;
    import dmocks.dynamic;
    import dmocks.qualifiers;
    import dmocks.call;

    private CallExpectation _expectation;

    private Call _setUpCall;

    this(CallExpectation expectation, Call setUpCall)
    {
        assert(expectation !is null, "can't create an ExpectationSetup if expectation is null");
        assert(setUpCall !is null, "can't create an ExpectationSetup if setUpCall is null");
        _expectation = expectation;
        _setUpCall = setUpCall;
    }

    /**
    * Ignore method argument values in matching calls to this expectation.
    */
    ExpectationSetup ignoreArgs()
    {
        _expectation.arguments = new ArgumentsTypeMatch(_setUpCall.arguments, (Dynamic a, Dynamic b) => true);
        return this;
    }

    /**
    * Allow providing custom argument comparator for matching calls to this expectation.
    */
    ExpectationSetup customArgsComparator(bool delegate(Dynamic expected, Dynamic provided) del)
    {
        _expectation.arguments = new ArgumentsTypeMatch(_setUpCall.arguments, del);
        return this;
    }

    /**
    * This expectation must match to at least min number of calls and at most to max number of calls.
    */
    ExpectationSetup repeat(int min, int max)
    {
        if (min > max)
        {
            throw new InvalidOperationException("The specified range is invalid.");
        }
        _expectation.repeatInterval = Interval(min, max);
        return this;
    }

    /**
    * This expectation will match exactly i times.
    */
    ExpectationSetup repeat(int i)
    {
        repeat(i, i);
        return this;
    }

    /**
    * This expectation will match to any number of calls.
    */
    ExpectationSetup repeatAny()
    {
        return repeat(0, int.max);
    }

    /**
    * When the method which matches this expectation is called execute the
    * given delegate. The delegate's signature must match the signature
    * of the called method. If it does not, an exception will be thrown.
    * The called method will return whatever the given delegate returns.
    * Examples:
    * ---
    * mocker.expect(myObj.myFunc(0, null, null, 'a')
    *     .ignoreArgs()
    *     .action((int i, char[] s, Object o, char c) { return -1; });
    * ---
    */
    ExpectationSetup action(T, U...)(T delegate(U) action)
    {
        _expectation.action.action = dynamic(action);
        return this;
    }

    // TODO: how can I get validation here that the type you're
    // inserting is the type expected before trying to execute it?
    // Not really an issue, since it'd be revealed in the space
    // of a single test.
    /**
    * Set the value to return when method matching this expectation is called on a mock object.
    * Params:
    *     value = the value to return
    */
    ExpectationSetup returns(T)(T value)
    {
        _expectation.action.returnValue = dynamic(value);
        return this;
    }

    /**
    * When the method which matches this expectation is called,
    * throw the given exception. If there are any
    * actions specified (via the action method), they will not be executed.
    */
    ExpectationSetup throws(Exception e)
    {
        _expectation.action.toThrow = e;
        return this;
    }

    /**
    * Instead of returning or throwing a given value, pass the call through to
    * the mocked type object. For mock***PassTo(obj) obj has to be valid for this to work.
    *
    * This is useful for example for enabling use of mock object in hashmaps by enabling
    * toHash and opEquals of your class.
    *
    * `opEquals` and `toString` are passed through automatically.
    */
    ExpectationSetup passThrough()
    {
        _expectation.action.passThrough = true;
        return this;
    }
}

/// backward compatibility alias
alias ExpectationSetup ExternalCall;

version (unittest)
{
    import std.exception;
    import std.stdio;

    class Templated(T)
    {
    }

    interface IM
    {
        void bar();
    }

    class ConstructorArg
    {
        this(int i)
        {
            a = i;
        }

        int a;
        int getA()
        {
            return a;
        }
    }

    class SimpleObject
    {
        this()
        {
        }

        void print()
        {
            writeln(toString());
        }
    }

    interface IRM
    {
        IM get();
        void set(IM im);
    }

    class HasPrivateMethods
    {
        protected void method()
        {
        }
    }

    interface IFace
    {
        void foo(string s);
    }

    class Smthng : IFace
    {
        void foo(string s)
        {
        }
    }

    class HasMember
    {
        int member;
    }

    class Overloads
    {
        void foo()
        {
        }

        void foo(int i)
        {
        }
    }

    class Qualifiers
    {
        int make() shared
        {
            return 0;
        }

        int make() const
        {
            return 1;
        }

        int make() shared const
        {
            return 2;
        }

        int make()
        {
            return 3;
        }

        int make() immutable
        {
            return 4;
        }
    }

    interface VirtualFinal
    {
        int makeVir();
    }

    class MakeAbstract
    {
        int con;
        this(int con)
        {
            this.con = con;
        }

        abstract int abs();

        int concrete()
        {
            return con;
        }
    }

    class FinalMethods : VirtualFinal
    {
        final int make()
        {
            return 0;
        }

        final int make(int i)
        {
            return 2;
        }

        int makeVir()
        {
            return 5;
        }
    }

    final class FinalClass
    {
        int fortyTwo()
        {
            return 42;
        }
    }

    class TemplateMethods
    {
        string get(T)(T t)
        {
            import std.traits;

            return fullyQualifiedName!T;
        }

        int getSomethings(T...)(T t)
        {
            return T.length;
        }
    }

    struct Struct
    {
        int get()
        {
            return 1;
        }
    }

    struct StructWithFields
    {
        int field;
        int get()
        {
            return field;
        }
    }

    struct StructWithConstructor
    {
        int field;
        this(int i)
        {
            field = i;
        }

        int get()
        {
            return field;
        }
    }

    class Dependency
    {
        private int[] arr = [1, 2];
        private int index = 0;
        public int foo()
        {
            return arr[index++];
        }
    }

    class TakesFloat
    {
        public void foo(float a)
        {
        }
    }

    class Property
    {
        private int _foo;
        @property int foo()
        {
            return _foo;
        }

        @property void foo(int i)
        {
            _foo = i;
        }

        @property T foot(T)()
        {
            static if (is(T == int))
            {
                return _foo;
            }
            else
            {
                return T.init;
            }
        }

        @property void foot(T)(T i)
        {
            static if (is(T == int))
            {
                _foo = i;
            }
        }
    }

}

@("nontemplated mock")
unittest
{
    (new Mocker()).mock!(Object);
}

@("templated mock")
unittest
{
    (new Mocker()).mock!(Templated!(int));
}

@("templated mock")
unittest
{
    (new Mocker()).mock!(IM);
}

@("execute mock method")
unittest
{
    auto mocker = new Mocker();
    auto obj = mocker.mock!(Object);

    obj.toString();
}

@("constructor argument")
unittest
{
    auto mocker = new Mocker();
    auto obj = mocker.mock!(ConstructorArg)(4);
}

@("lastCall")
unittest
{
    Mocker mocker = new Mocker();
    SimpleObject obj = mocker.mock!(SimpleObject);
    obj.print;
    auto e = mocker.lastCall;

    assert(e !is null);
}

private class TestClass
{
    string test()
    {
        return "test";
    }

    string test1()
    {
        return "test 1";
    }

    string test2()
    {
        return "test 2";
    }
}

@("return a value")
unittest
{
    Mocker mocker = new Mocker();
    TestClass cl = mocker.mock!(TestClass);
    cl.test;
    auto e = mocker.lastCall;

    assert(e !is null);
    e.returns("frobnitz");
}

@("unexpected call")
unittest
{
    Mocker mocker = new Mocker();
    TestClass cl = mocker.mock!(TestClass);
    mocker.replay();
    assertThrown!ExpectationViolationError(cl.test);
}

@("expect")
unittest
{
    Mocker mocker = new Mocker();
    TestClass cl = mocker.mock!(TestClass);
    mocker.expect(cl.test).repeat(0).returns("mrow?");
    mocker.replay();
    assertThrown!ExpectationViolationError(cl.test);
}

@("repeat single")
unittest
{
    Mocker mocker = new Mocker();
    TestClass cl = mocker.mock!(TestClass);
    mocker.expect(cl.test).repeat(2).returns("foom?");

    mocker.replay();

    cl.test;
    cl.test;
    assertThrown!ExpectationViolationError(cl.test);
}

@("repository match counts")
unittest
{
    auto mocker = new Mocker();
    auto cl = mocker.mock!(TestClass);

    cl.test;
    mocker.lastCall().repeat(2, 2).returns("mew.");
    mocker.replay();
    assertThrown!ExpectationViolationError(mocker.verify());
}

@("delegate payload")
unittest
{
    bool calledPayload = false;
    auto mocker = new Mocker();
    auto obj = mocker.mock!(SimpleObject);

    //obj.print;
    mocker.expect(obj.print).action({ calledPayload = true; });
    mocker.replay();

    obj.print;
    assert(calledPayload);
}

@("delegate payload with mismatching parameters")
unittest
{
    auto mocker = new Mocker();
    auto obj = mocker.mock!(SimpleObject);

    //o.print;
    mocker.expect(obj.print).action((int) {});
    mocker.replay();

    assertThrown!Error(obj.print);
}

@("exception payload")
unittest
{
    Mocker mocker = new Mocker();
    auto obj = mocker.mock!(SimpleObject);

    string msg = "divide by cucumber error";
    obj.print;
    mocker.lastCall().throws(new Exception(msg));
    mocker.replay();

    try
    {
        obj.print;
        assert(false, "expected exception not thrown");
    }
    catch (Exception e)
    {
        // Careful -- assertion errors derive from Exception
        assert(e.msg == msg, e.msg);
    }
}

@("passthrough")
unittest
{
    Mocker mocker = new Mocker();
    auto cl = mocker.mock!(TestClass);
    cl.test;
    mocker.lastCall().passThrough();

    mocker.replay();
    string str = cl.test;
    assert(str == "test", str);
}

@("class with constructor init check")
unittest
{
    auto mocker = new Mocker();
    auto obj = mocker.mock!(ConstructorArg)(4);
    obj.getA();
    mocker.lastCall().passThrough();
    mocker.replay();
    assert(4 == obj.getA());
}

@("associative arrays")
unittest
{
    Mocker mocker = new Mocker();
    auto obj = mocker.mock!(Object);
    mocker.expect(obj.toHash()).passThrough().repeatAny;
    mocker.expect(obj.opEquals(null)).ignoreArgs().passThrough().repeatAny;

    mocker.replay();
    int[Object] i;
    i[obj] = 5;
    int j = i[obj];
}

@("ordering in order")
unittest
{
    Mocker mocker = new Mocker();
    auto obj = mocker.mock!(Object);
    mocker.ordered;
    mocker.expect(obj.toHash).returns(cast(hash_t) 5);
    mocker.expect(obj.toString).returns("mow!");

    mocker.replay();
    obj.toHash;
    obj.toString;
    mocker.verify;
}

@("ordering not in order")
unittest
{
    Mocker mocker = new Mocker();
    auto cl = mocker.mock!(TestClass);
    mocker.ordered;
    mocker.expect(cl.test1).returns("mew!");
    mocker.expect(cl.test2).returns("mow!");

    mocker.replay();

    assertThrown!ExpectationViolationError(cl.test2);
}

@("ordering interposed")
unittest
{
    Mocker mocker = new Mocker();
    auto obj = mocker.mock!(SimpleObject);
    mocker.ordered;
    mocker.expect(obj.toHash).returns(cast(hash_t) 5);
    mocker.expect(obj.toString).returns("mow!");
    mocker.unordered;
    obj.print;

    mocker.replay();
    obj.toHash;
    obj.print;
    obj.toString;
}

@("allow unexpected")
unittest
{
    Mocker mocker = new Mocker();
    auto obj = mocker.mock!(Object);
    mocker.ordered;
    mocker.allowUnexpectedCalls(true);
    mocker.expect(obj.toString).returns("mow!");
    mocker.replay();
    obj.toHash; // unexpected tohash calls
    obj.toString;
    obj.toHash;
    assertThrown!ExpectationViolationError(mocker.verify(false, true));
    mocker.verify(true, false);
}

@("allowing")
unittest
{
    Mocker mocker = new Mocker();
    auto obj = mocker.mock!(Object);
    mocker.allowing(obj.toString).returns("foom?");

    mocker.replay();
    obj.toString;
    obj.toString;
    obj.toString;
    mocker.verify;
}

@("nothing for method to do")
unittest
{
    try
    {
        Mocker mocker = new Mocker();
        auto cl = mocker.mock!(TestClass);
        mocker.allowing(cl.test);

        mocker.replay();
        assert(false, "expected a mocks setup exception");
    }
    catch (MocksSetupException e)
    {
    }
}

@("allow defaults test")
unittest
{
    Mocker mocker = new Mocker();
    auto cl = mocker.mock!(TestClass);
    mocker.allowDefaults;
    mocker.allowing(cl.test);

    mocker.replay();
    assert(cl.test == (char[]).init);
}

// Going through the guts of Smthng
// unittest
// {
//     auto foo = new Smthng();
//     auto guts = *(cast(int**)&foo);
//     auto len = __traits(classInstanceSize, Smthng) / size_t.sizeof; 
//     auto end = guts + len;
//     for (; guts < end; guts++) {
//         writefln("\t%x", *guts);
//     } 
// }

@("mock interface")
unittest
{
    auto mocker = new Mocker;
    IFace obj = mocker.mock!(IFace);
    debugLog("about to call once...");
    obj.foo("hallo");
    mocker.replay;
    debugLog("about to call twice...");
    obj.foo("hallo");
    mocker.verify;
}

@("cast mock to interface")
unittest
{
    auto mocker = new Mocker;
    IFace obj = mocker.mock!(Smthng);
    debugLog("about to call once...");
    obj.foo("hallo");
    mocker.replay;
    debugLog("about to call twice...");
    obj.foo("hallo");
    mocker.verify;
}

@("cast mock to interface")
unittest
{
    auto mocker = new Mocker;
    IFace obj = mocker.mock!(Smthng);
    debugLog("about to call once...");
    obj.foo("hallo");
    mocker.replay;
    debugLog("about to call twice...");
    obj.foo("hallo");
    mocker.verify;
}

@("return user-defined type")
unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mock!(IRM);
    auto im = mocker.mock!(IM);
    debugLog("about to call once...");
    mocker.expect(obj.get).returns(im);
    obj.set(im);
    mocker.replay;
    debugLog("about to call twice...");
    assert(obj.get is im, "returned the wrong value");
    obj.set(im);
    mocker.verify;
}

@("return user-defined type")
unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mock!(HasMember);
}

@("overloaded method")
unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mock!(Overloads);
    obj.foo();
    obj.foo(1);
    mocker.replay;
    obj.foo(1);
    obj.foo;
    mocker.verify;
}

@("overloaded method qualifiers")
unittest
{
    {
        auto mocker = new Mocker;
        auto s = mocker.mock!(shared(Qualifiers));
        auto sc = cast(shared const) s;

        mocker.expect(s.make).passThrough;
        mocker.expect(sc.make).passThrough;
        mocker.replay;

        assert(s.make == 0);
        assert(sc.make == 2);

        mocker.verify;
    }
    {
        auto mocker = new Mocker;
        auto m = mocker.mock!(Qualifiers);
        auto c = cast(const) m;
        auto i = cast(immutable) m;

        mocker.expect(i.make).passThrough;
        mocker.expect(m.make).passThrough;
        mocker.expect(c.make).passThrough;
        mocker.replay;

        assert(i.make == 4);
        assert(m.make == 3);
        assert(c.make == 1);

        mocker.verify;
    }
    {
        auto mocker = new Mocker;
        auto m = mocker.mock!(Qualifiers);
        auto c = cast(const) m;
        auto i = cast(immutable) m;

        mocker.expect(i.make).passThrough;
        mocker.expect(m.make).passThrough;
        mocker.expect(m.make).passThrough;
        mocker.replay;

        assert(i.make == 4);
        assert(m.make == 3);
        assertThrown!ExpectationViolationError(c.make);
    }
}

@("final mock of virtual methods")
unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockFinal!(VirtualFinal);
    mocker.expect(obj.makeVir()).returns(5);
    mocker.replay;
    assert(obj.makeVir == 5);
}

@("final mock of abstract methods")
unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockFinal!(MakeAbstract)(6);
    mocker.expect(obj.concrete()).passThrough;
    mocker.replay;
    assert(obj.concrete == 6);
    mocker.verify;
}

@("final methods")
unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockFinal!(FinalMethods);
    mocker.expect(obj.make()).passThrough;
    mocker.expect(obj.make(1)).passThrough;
    mocker.replay;
    static assert(!is(typeof(o) == FinalMethods));
    assert(obj.make == 0);
    assert(obj.make(1) == 2);
    mocker.verify;
}

@("final class")
unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockFinal!(FinalClass);
    mocker.expect(obj.fortyTwo()).passThrough;
    mocker.replay;
    assert(obj.fortyTwo == 42);
    mocker.verify;
}

@("final class with no underlying object")
unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockFinalPassTo!(FinalClass)(null);
    mocker.expect(obj.fortyTwo()).returns(43);
    mocker.replay;
    assert(obj.fortyTwo == 43);
    mocker.verify;
}

@("template methods")
unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockFinal!(TemplateMethods);
    mocker.expect(obj.get(1)).passThrough;
    mocker.expect(obj.getSomethings(1, 2, 3)).passThrough;
    mocker.replay;
    assert(obj.get(1) == "int");
    auto tm = new TemplateMethods();
    assert(obj.getSomethings(1, 2, 3) == 3);
    mocker.verify;
}

@("struct")
unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockStruct!(Struct);
    mocker.expect(obj.get).passThrough;
    mocker.replay;
    assert(obj.get() == 1);
    mocker.verify;
}

@("struct with fields")
unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockStruct!(StructWithFields)(5);
    mocker.expect(obj.get).passThrough;
    mocker.replay;
    assert(obj.get() == 5);
    mocker.verify;
}

@("struct with fields")
unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockStruct!(StructWithConstructor)(5);
    mocker.expect(obj.get).passThrough;
    mocker.replay;
    assert(obj.get() == 5);
    mocker.verify;
}

@("struct with no underlying object")
unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockStructPassTo(StructWithConstructor.init);
    mocker.expect(obj.get).returns(6);
    mocker.replay;
    assert(obj.get() == 6);
    mocker.verify;
}

@("returning different values on the same expectation")
unittest
{
    auto mocker = new Mocker;
    auto dependency = mocker.mock!Dependency;

    //mocker.ordered;
    mocker.expect(dependency.foo).returns(1);
    mocker.expect(dependency.foo).returns(2);
    mocker.replay;
    assert(dependency.foo == 1);
    assert(dependency.foo == 2);
    mocker.verify;
}

@("customArgsComparator")
unittest
{
    import std.math;

    auto mocker = new Mocker;
    auto dependency = mocker.mock!TakesFloat;
    mocker.expect(dependency.foo(1.0f)).customArgsComparator(
            (Dynamic a, Dynamic b) {
        if (a.type == typeid(float))
        {
            return (abs(a.get!float() - b.get!float()) < 0.1f);
        }
        return true;
    }).repeat(2);
    mocker.replay;

    // custom comparison example - treat similar floats as equals
    dependency.foo(1.01);
    dependency.foo(1.02);
}

unittest
{
    auto mocker = new Mocker;
    auto dependency = mocker.mockFinal!Property;
    mocker.ordered;
    mocker.expect(dependency.foo = 2).ignoreArgs.passThrough;
    mocker.expect(dependency.foo).passThrough;
    //TODO: these 2 don't work yet
    //mocker.expect(dependency.foot!int = 5).passThrough;
    //mocker.expect(dependency.foot!int).passThrough;
    mocker.replay;

    dependency.foo = 7;
    assert(dependency.foo == 7);
    //dependency.foot!int = 3;
    //assert(dependency.foot!int == 3);
    mocker.verify;
}

/*TODO - typesafe variadic methods do not work yet
class Foo {
    int x;
    string s;

    this(int x, string s) {
        this.x = x;
        this.s = s;
    }
}

class Varargs
{
    import core.vararg;

    int varDyn(int first, ...)
    {
        return vvarDyn(first, _arguments, _argptr);
    }

    // idiom from C - for every dynamic vararg function there has to be vfunction(Args, TypeInfo[] arguments, va_list argptr)
    // otherwise passThrough is impossible
    int vvarDyn(int first, TypeInfo[] arguments, va_list argptr)
    {
        assert(arguments[0] == typeid(int));
        int second = va_arg!int(argptr);
        return first + second;
    }

    int varArray(int first, int[] next...)
    {
        return first + next[0];
    }

    int varClass(int first, Foo f...)
    {
        return first + f.x;
    }
}

unittest 
{
    import core.vararg;

    auto mocker = new Mocker;
    auto dependency = mocker.mock!Varargs;
    mocker.record;
    // we only specify non-vararg arguments in setup because typeunsafe varargs can't have meaningful operations on them (like comparision, etc)
    mocker.expect(dependency.varDyn(42)).passThrough; // passThrough works with typeunsafe vararg functions only when v[funcname](Args, Typeinfo[], va_list) function variant is provided
    mocker.replay;

    assert(dependency.varDyn(42, 5) == 47);
}*/
