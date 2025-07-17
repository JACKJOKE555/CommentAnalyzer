// This file is used for testing the PROJECT_MEMBER_MISSING_TYPEPARAM rule.
// It contains a generic method with a type parameter that is not documented.

namespace TestCases
{
    class ClassWithMethodMissingTypeParam
    {
        /// <summary>
        /// A test method.
        /// </summary>
        /// <remarks>Some remarks.</remarks>
        public void TestMethod<T>(T param) 
        { 
        }
    }
} 