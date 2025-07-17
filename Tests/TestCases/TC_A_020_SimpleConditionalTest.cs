using System;

namespace TestCases
{
    public class SimpleConditionalTest
    {
        public string TestField = "test";

#if DEBUG
        public void DebugMethod()
        {
            Console.WriteLine("Debug");
        }
#endif

        public void NormalMethod()
        {
            Console.WriteLine("Normal");
        }
    }
} 