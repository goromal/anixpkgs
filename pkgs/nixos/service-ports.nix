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
  tactical = {
    insecure = 60060;
    web = 60070;
  };
}
