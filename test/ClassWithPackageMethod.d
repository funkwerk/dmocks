module test.ClassWithPackageMethod;

import dmocks.mocks;

@("class with package method")
unittest
{
    auto mocker = new Mocker;

    // dmocks shouldn't try to mock foo
    mocker.mock!Class;
}

class Class
{
    package void foo() { }
}
