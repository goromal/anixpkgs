{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.machines.localLlm;
  extendedPkgs = pkgs.extend (import ../../../overlay.nix);
  baseUrl = "http://${cfg.host}:${toString cfg.port}";
in
{
  options.machines.localLlm = {
    enable = lib.mkEnableOption "private local LLM service and CLI";
    model = lib.mkOption {
      type = lib.types.str;
      default = "qwen3.5:35b-a3b";
      description = "Ollama model loaded declaratively and used by anix-llm.";
    };
    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Loopback address for the Ollama API.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Port for the Ollama API.";
    };
    contextLength = lib.mkOption {
      type = lib.types.ints.positive;
      default = 32768;
      description = "Default Ollama context length.";
    };
    acceleration = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          false
          "rocm"
          "cuda"
          "vulkan"
        ]
      );
      default = null;
      description = "Ollama hardware acceleration backend.";
    };
    disableCloud = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable Ollama cloud inference and web search.";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = extendedPkgs.anix-llm;
      description = "Unified local LLM CLI package.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.elem cfg.host [
          "127.0.0.1"
          "::1"
          "localhost"
        ];
        message = "machines.localLlm.host must remain loopback-only.";
      }
    ];

    services.ollama = {
      enable = true;
      inherit (cfg) acceleration host port;
      loadModels = [ cfg.model ];
      environmentVariables = {
        OLLAMA_CONTEXT_LENGTH = toString cfg.contextLength;
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_KV_CACHE_TYPE = "q8_0";
        OLLAMA_NO_CLOUD = if cfg.disableCloud then "1" else "0";
        OLLAMA_DEBUG_LOG_REQUESTS = "0";
      };
    };

    environment.systemPackages = [ cfg.package ];
    environment.sessionVariables = {
      ANIX_LLM_MODEL = cfg.model;
      ANIX_LLM_URL = baseUrl;
      OLLAMA_NOHISTORY = "1";
      OLLAMA_NO_CLOUD = if cfg.disableCloud then "1" else "0";
    };
  };
}
