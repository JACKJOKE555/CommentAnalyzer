/// <summary>
/// ShouldBeForMethodA —— [method职责简述]
/// </summary>
#if CONDITION
public void MethodB() { }
#endif
#if !CONDITION
public void MethodA() { }
#endif 