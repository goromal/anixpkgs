# Default Codex configuration values, referenced by profiles.
{
  marketplaces = [ "google/elephant-goldfish-model" ];
  plugins = [ "egm@egm" ];
  model = "gpt-6-astra";
  modelProvider = "openai";
  approvalPolicy = "never";
  sandboxMode = "danger-full-access";
  extraSettings = {
    model_reasoning_effort = "medium";
  };
}
