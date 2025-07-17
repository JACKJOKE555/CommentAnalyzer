// This file is used for testing the PROJECT_MEMBER_MISSING_PARAM rule.
// It contains a method with a parameter that is not documented.

namespace TestCases
{
    class ClassWithMethodMissingParam
    {
        /// <summary>
        /// A test method.
        /// </summary>
        /// <remarks>Some remarks.</remarks>
        public void TestMethod(int undocumentedParam) 
        { 
        }
    }
} 