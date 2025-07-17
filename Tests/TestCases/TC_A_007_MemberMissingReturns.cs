// This file is used for testing the PROJECT_MEMBER_MISSING_RETURNS rule.
// It contains a method with a return value that is not documented.

namespace TestCases
{
    class ClassWithMethodMissingReturns
    {
        /// <summary>
        /// A test method.
        /// </summary>
        /// <remarks>Some remarks.</remarks>
        public int TestMethod() 
        { 
            return 1;
        }
    }
} 