import dmocks.mocks;

// Bug #4: https://github.com/funkwerk/DMocks-revived/issues/4
unittest
{
    static struct S
    {
        @disable this();
        this(string foo)
        {
        }
    }

    interface I
    {
        S foo();
    }

    auto mocker = new Mocker;
    mocker.mock!I;
}
