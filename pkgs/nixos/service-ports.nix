{
  orchestrator = 40040;
  rankserver = 4018;
  stampserver = 5018;
  statsd = 9000;
  prometheus = {
    input = 9598;
    output = 9001;
  };
  node-exporter = 5554;
  loki = 3666;
  grafana = {
    internal = 5555;
    public = 5556;
  };
  authui = 4242;
  budget_ui = 4343;
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
    # NB: keep both clear of the browser-restricted "unsafe port" list (Chromium &
    # Firefox refuse to navigate to them, e.g. the 6665-6669 IRC range, 6697, 6566).
    # The public port is opened in a browser; the internal port is opened by the
    # Electron shell (also Chromium). 6666/6667 are IRC ports -> silently blocked.
    internal = 6868;
    public = 6869;
  };
  navidrome = 4533;
  la-quiz-web = 5656;
  tester = 5757;
  disciple = 6363;
  launchpad = 8888;
  comfyui = 8188;
  anix_upgrade_ui = 5858;
  tasks_ui = 5959;
  videodl = 6060;
  intake_ui = 6161;
  cozy = 6262;
  sunset = 6464;
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
