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
  tactical = {
    insecure = 60060;
    web = 60070;
  };
  vikunja = {
    internal = 3456;
    public = 3457;
  };
  la-quiz-web = 5656;
  tester = 5757;
  ladder = {
    internal = 8181;
    public = 8282;
  };
  flaresolverr = 8191;
}
