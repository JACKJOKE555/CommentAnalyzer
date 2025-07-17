// This file is used for testing the PROJECT_TYPE_NESTED_TYPE rule.
// It contains a class that nests another class inside it.

namespace TestCases
{
    /// <summary>A class.</summary>
    /// <remarks>Some remarks.</remarks>
    class OuterClass
    {
        /// <summary>A nested class.</summary>
        /// <remarks>Some remarks.</remarks>
        class NestedClass
        {
        }
    }
} 