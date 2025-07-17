// This file is used for testing the PROJECT_TYPE_NESTED_ENUM rule.
// It contains a class that nests an enum inside it.

namespace TestCases
{
    /// <summary>A class.</summary>
    /// <remarks>Some remarks.</remarks>
    class OuterClassWithEnum
    {
        /// <summary>A nested enum.</summary>
        /// <remarks>Some remarks.</remarks>
        public enum NestedEnum
        {
            Value1,
            Value2
        }
    }
} 