# Every profile must explicitly select each capability in this catalog.
# Keep dependencies inside feature modules; adding an application here must not
# silently enable it on existing machines.
{
  desktop = "GNOME desktop, printing and captive-portal browser";
  development = "development tools and editor integration";
  recreation = "recreational packages and emulator device rules";
  headsetAudio = "PipeWire and Bluetooth headset tuning";
  externalDrives = "known external-drive automounts";
  homeVpn = "manual home VPN client";
  agentUi = "workspace agent terminal web UI";
  upgradeUi = "anix-upgrade web UI";
  fileServers = "rank and stamp file servers";
  metrics = "host metrics, logs and Grafana";
  notesWiki = "notes wiki web site";
  orchestrator = "scheduled jobs, orchestrator daemon and web UI";
  auth = "credential refresh UI and command";
  budget = "budget reporting web UI";
  languageQuiz = "language quiz web application";
  music = "Navidrome music server";
  tester = "tester web application";
  disciple = "disciple web application";
  tasks = "tasks web UI";
  tactical = "Daily Tactical service";
  videoDownload = "video download web application";
  brom = "Brom web application";
  intake = "intake web UI";
  mail = "mail server and mail web UI";
  plex = "Plex media server";
  vikunja = "Vikunja task management";
  gameStreaming = "Sunshine game streaming and Sunset UI";
  gpu = "CUDA development tooling";
  notebooks = "Launchpad Jupyter notebook server";
  imageGeneration = "ComfyUI backend and Cozy image-generation UI";
  localLlm = "private local LLM service and CLI";
  folio = "Folio book study backend and optional desktop shell";
}
