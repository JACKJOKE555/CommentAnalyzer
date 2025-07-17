// This file is used for testing the PROJECT_TYPE_MULTI_ENUM_FILE rule.
// It contains two enums defined in the same file at the top level.

namespace TestCases
{
    /// <summary>First enum.</summary>
    public enum FirstEnumInFile
    {
        A, B
    }

    /// <summary>Second enum.</summary>
    public enum SecondEnumInFile
    {
        C, D
    }
} 