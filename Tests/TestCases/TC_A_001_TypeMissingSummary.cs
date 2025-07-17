// This file is used for testing the PROJECT_TYPE_MISSING_SUMMARY rule.
// It contains types that have a documentation block but are missing the <summary> tag.

namespace TestCases
{
    /// <remarks>This is a class for testing.</remarks>
    class ClassMissingSummary
    {
    }

    /// <remarks>This is a struct for testing.</remarks>
    struct StructMissingSummary
    {
    }

    /// <remarks>This is an interface for testing.</remarks>
    interface IInterfaceMissingSummary
    {
    }

    /// <remarks>This is an enum for testing.</remarks>
    enum EnumMissingSummary
    {
        A, B, C
    }
} 