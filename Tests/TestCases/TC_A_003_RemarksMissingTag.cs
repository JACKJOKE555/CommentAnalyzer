// This file is used for testing the PROJECT_TYPE_MISSING_REMARKS_TAG rule.
// It contains a type that has a remarks tag, but the tag is empty
// or missing the required structured content.

namespace TestCases
{
    /// <summary>
    /// This is a test class.
    /// </summary>
    /// <remarks>
    /// 
    /// </remarks>
    class ClassWithEmptyRemarks
    {
    }
} 