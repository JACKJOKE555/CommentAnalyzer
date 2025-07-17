// This file is used for testing the PROJECT_MEMBER_MISSING_REMARKS rule.
// It contains a member that is missing the <remarks> tag.

namespace TestCases
{
    class ClassWithMemberMissingRemarks
    {
        /// <summary>
        /// A test method.
        /// </summary>
        public void TestMethod() { }
    }
} 