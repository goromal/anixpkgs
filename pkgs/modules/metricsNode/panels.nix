# Shared constants for Grafana dashboard generation.
#
# These uids are pinned deliberately: Grafana otherwise assigns database-generated
# uids per host, which is why hand-exported dashboards were only ever valid on the
# host that produced them.
#
# Kept in sync by hand with `PROM_UID`/`LOKI_UID` in
# pkgs/python-packages/grafana-dash/dashgen.py, which renders and lints against
# its own copies. Changing one without the other passes lint and breaks at runtime.
{
  prometheusUid = "anix-prometheus";
  lokiUid = "anix-loki";
}
