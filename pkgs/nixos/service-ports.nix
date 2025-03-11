{
  orchestrator = 40040;
  rankserver = 4018;
  statsd = 9000;
  prometheus = {
    input = 9598;
    output = 9001;
  };
  grafana = {
    internal = 5555;
    public = 5556;
  };
}
