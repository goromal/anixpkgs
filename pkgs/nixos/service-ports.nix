{
  orchestrator = 40040;
  bitd = 40041;
  rankserver = 4018;
  stampserver = 5018;
  statsd = 9000;
  prometheus = {
    input = 9598;
    output = 9001;
  };
  # UI usage heartbeats: nginx -> local vector (beacon), spoke vector -> hub
  # vector (hub), and the hub's usage-only Prometheus exporter (exporter).
  usage = {
    beacon = 9599;
    hub = 9600;
    exporter = 9601;
  };
  node-exporter = 5554;
  nix-exporter = 9944;
  loki = 3666;
  grafana = {
    internal = 5555;
    public = 5556;
  };
  authui = 4242;
  budget_ui = 4343;
  budget_ui_agent_terminal = 4344;
  assistant_ui = 4646;
  assistant_ui_agent_terminal = 4647;
  orchestrator_ui = 4545;
  tactical = {
    insecure = 60060;
    web = 60070;
  };
  vikunja = {
    internal = 3456;
    public = 3457;
  };
  folio = {
    internal = 6868;
    public = 6869;
    agentTerminal = 6870;
  };
  navidrome = 4533;
  la-quiz-web = 5656;
  tester = 5757;
  disciple = 6363;
  launchpad = 8888;
  comfyui = 8188;
  anix_upgrade_ui = 5858;
  nexus_ui = 6969;
  agent_ui = {
    web = 6767;
    terminal = 6768;
  };
  tasks_ui = 5959;
  videodl = 6060;
  brom = 6700;
  brom-aria2-rpc = 6800;
  intake_ui = 6161;
  cozy = 6262;
  sunset = 6464;
  rcrsync_ui = 4747;
  mail_ui = 6565;
  # Micro XRCE-DDS agent UDP port (Ardupilot AP_DDS -> ROS2 bridge; matches
  # the Ardupilot default DDS_UDP_PORT)
  xrce-dds-agent = 2019;
  mavlink = {
    # Ardupilot SITL serial0 TCP server (-S -I 0 convention: 5760 + 10 * instance)
    ap-sitl-tcp = 5760;
    # mavlink-router TCP listen port (moved off the default 5760 to avoid
    # colliding with a colocated SITL instance)
    router-tcp = 5790;
  };
}
