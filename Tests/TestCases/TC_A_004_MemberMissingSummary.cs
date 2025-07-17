// This file is used for testing the PROJECT_MEMBER_MISSING_SUMMARY rule.
// It contains members that have documentation blocks but are missing the <summary> tag.

namespace TestCases
{
    class ClassWithMembersMissingSummary
    {
        /// <remarks>A test constructor.</remarks>
        public ClassWithMembersMissingSummary() { }

        /// <remarks>A test field.</remarks>
        public int TestField;

        /// <remarks>A test property.</remarks>
        public string TestProperty { get; set; }

        /// <remarks>A test event.</remarks>
        public event System.Action TestEvent;

        /// <remarks>A test method.</remarks>
        public void TestMethod() { }
    }
} 