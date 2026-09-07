# Default Codex configuration values, referenced by profiles.
{
  model = "gpt-5.6";
  modelProvider = "openai";
  approvalPolicy = "never";
  sandboxMode = "danger-full-access";
  extraSettings = {
    model_reasoning_effort = "medium";
  };
}
