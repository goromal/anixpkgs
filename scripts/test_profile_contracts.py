#!/usr/bin/env python3
"""Profile behavior contracts, including negative service and schema checks.

Run with the repository's NIXOS_VERSION channel. Package defaults resolve to
this checkout during the suite; dependencies.nix is restored exactly afterward.
"""

import contextlib
import io
import json
import os
import subprocess
import unittest

from smoke_test_profiles import (
    NIXOS_DIR,
    NIXOS_STATE,
    REPO_ROOT,
    _LocalBuildPatch,
    eval_config,
)


COMMON = {
    "agent_ui",
    "anix-upgrade-ui",
    "metricsNode",
    "nginx",
    "orchestrator_ui",
    "orchestratord",
    "rankserver",
    "stampserver",
}
PERSONAL = COMMON | {"folio-backend", "homeVpnNode", "sunset", "sunshine"}
ATS = COMMON | {
    "authui",
    "budget_ui",
    "disciple",
    "folio-backend",
    "intake_ui",
    "la-quiz-web",
    "mailNode",
    "mail_ui",
    "navidrome-ats",
    "notes-wiki",
    "plexNode",
    "tacticald",
    "tasks_ui",
    "tester",
    "vdlserver",
    "vikunja-ats",
}
JETPACK = COMMON | {"brom", "comfyui", "launchpad"}


def fixture(profile, extra=""):
    return f"""
    {{ lib, ... }}: {{
      imports = [ {NIXOS_DIR}/profiles/{profile}.nix ];
      machines.base.nixosState = "{NIXOS_STATE}";
      networking.hostName = "profile-test";
      fileSystems."/" = {{ device = "none"; fsType = "tmpfs"; }};
      boot.loader.systemd-boot.enable = lib.mkForce false;
      {extra}
    }}
    """


def evaluate(configuration):
    return subprocess.run(
        [
            "nix",
            "eval",
            "--impure",
            "--json",
            "--expr",
            f"import {REPO_ROOT}/scripts/profile_snapshot.nix "
            f"{{ configuration = {configuration}; }}",
        ],
        env={
            **os.environ,
            "NIXPKGS_ALLOW_UNFREE": "1",
            "NIXPKGS_ALLOW_INSECURE": "1",
            "NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM": "1",
        },
        capture_output=True,
        text=True,
        timeout=300,
    )


def evaluate_flake(machine):
    return subprocess.run(
        [
            "nix",
            "eval",
            "--impure",
            "--json",
            "--expr",
            f'import {REPO_ROOT}/scripts/profile_snapshot.nix '
            f'{{ evaluated = (builtins.getFlake "{REPO_ROOT}").nixosConfigurations.{machine}; }}',
        ],
        env={
            **os.environ,
            "NIXPKGS_ALLOW_UNFREE": "1",
            "NIXPKGS_ALLOW_INSECURE": "1",
            "NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM": "1",
        },
        capture_output=True,
        text=True,
        timeout=300,
    )


class ProfileContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        patch = _LocalBuildPatch()
        patch.__enter__()
        cls.addClassCleanup(patch.__exit__, None, None, None)
        cls.snapshots = {}

    def snapshot(self, configuration):
        if configuration not in self.snapshots:
            result = evaluate(configuration)
            self.assertEqual(result.returncode, 0, result.stderr[-6000:])
            self.snapshots[configuration] = json.loads(result.stdout)
        result = self.snapshots[configuration]
        self.assertEqual(result["failedAssertions"], [])
        return result

    def flake_snapshot(self, machine):
        key = f"flake:{machine}"
        if key not in self.snapshots:
            result = evaluate_flake(machine)
            self.assertEqual(result.returncode, 0, result.stderr[-6000:])
            self.snapshots[key] = json.loads(result.stdout)
        result = self.snapshots[key]
        self.assertEqual(result["failedAssertions"], [])
        return result

    def rejected(self, configuration, message):
        result = evaluate(configuration)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(message, result.stderr)

    def test_profile_service_sets(self):
        for profile, expected in [
            ("workstation", set()),
            ("personal", PERSONAL),
            ("ats", ATS),
        ]:
            with self.subTest(profile=profile):
                snapshot = self.snapshot(fixture(profile))
                self.assertEqual(set(snapshot["enabledServices"]), expected)

    def test_concrete_machine_service_sets(self):
        for name, expected in [
            ("personal-inspiron", PERSONAL),
            ("personal-panasonic", PERSONAL),
            ("personal-dell", PERSONAL | {"launchpad", "comfyui", "ollama"}),
            ("ats-alderlake", ATS),
            ("ats-pi", ATS),
        ]:
            with self.subTest(machine=name):
                snapshot = self.snapshot(f"{NIXOS_DIR}/configurations/{name}.nix")
                self.assertEqual(set(snapshot["enabledServices"]), expected)
                self.assertEqual(
                    snapshot["jobs"].count("launchpad-sync"),
                    1 if "launchpad" in expected else 0,
                )

        for machine in ["jetson-orin-nx", "jetson-orin-agx"]:
            with self.subTest(machine=machine):
                snapshot = self.flake_snapshot(machine)
                self.assertEqual(set(snapshot["enabledServices"]), JETPACK)
                self.assertEqual(snapshot["jobs"].count("launchpad-sync"), 1)

    def test_workstation_has_agents_without_web_server(self):
        snapshot = self.snapshot(fixture("workstation"))
        self.assertEqual(snapshot["frameworks"], ["claude"])
        self.assertTrue(snapshot["claudePlugins"])
        self.assertNotIn("agent-ui", snapshot["units"])
        self.assertNotIn("agent-ui-terminal", snapshot["units"])
        self.assertNotIn("nginx", snapshot["units"])
        self.assertFalse({80, 443} & set(snapshot["tcpPorts"]))
        self.assertFalse(any(snapshot["routes"].values()))
        self.assertEqual(snapshot["webServices"], [])

    def test_agent_ui_brings_its_dependencies(self):
        snapshot = self.snapshot(
            fixture(
                "workstation",
                """
          machines.features.agentUi.enable = lib.mkForce true;
          machines.features.development.enable = lib.mkForce false;
        """,
            )
        )
        self.assertEqual(set(snapshot["enabledServices"]), {"agent_ui", "nginx"})
        self.assertTrue(
            {"agent-ui", "agent-ui-terminal", "nginx"} <= set(snapshot["units"])
        )
        self.assertTrue({80, 443} <= set(snapshot["tcpPorts"]))
        self.assertIn("/agents/", snapshot["routes"]["profile-test.local"])

    def test_disabled_orchestrator_has_no_jobs_or_timers(self):
        snapshot = self.snapshot(
            fixture(
                "personal",
                """
          machines.features.orchestrator.enable = lib.mkForce false;
        """,
            )
        )
        self.assertTrue(snapshot["jobs"])
        for name in snapshot["jobs"] + [
            "weekly-orchestratord-restart",
            "orchestratord",
        ]:
            self.assertNotIn(name, snapshot["units"])
            self.assertNotIn(name, snapshot["timers"])
        self.assertNotIn("orchestrator_ui", snapshot["enabledServices"])
        self.assertFalse(
            any("orchestrator-blacklist" in rule for rule in snapshot["tmpfiles"])
        )
        for name in snapshot["jobs"]:
            self.assertNotIn(f"{name} Logs", snapshot["jobPanels"])

    def test_determinate_preserves_mutable_netrc(self):
        snapshot = self.snapshot(fixture("workstation"))
        determinate = json.loads(snapshot["determinateConfig"])
        self.assertEqual(
            determinate["authentication"]["additionalNetrcSources"],
            ["/etc/nix/netrc"],
        )
        self.assertIn("f /etc/nix/netrc 0600 root root -", snapshot["tmpfiles"])

    def test_gpu_support_does_not_start_applications(self):
        snapshot = self.snapshot(
            fixture(
                "workstation",
                """
          machines.features.gpu.enable = lib.mkForce true;
          services.xserver.videoDrivers = [ "nvidia" ];
          hardware.nvidia.open = false;
        """,
            )
        )
        self.assertTrue(snapshot["cuda"])
        self.assertEqual(snapshot["enabledServices"], [])
        self.assertFalse(
            {"launchpad", "comfyui", "cozy", "nginx"} & set(snapshot["units"])
        )

    def test_applications_can_be_selected_independently(self):
        for feature, service in [
            ("notebooks", "launchpad"),
            ("imageGeneration", "comfyui"),
        ]:
            with self.subTest(feature=feature):
                snapshot = self.snapshot(
                    fixture(
                        "workstation",
                        f"""
                  machines.features.{feature}.enable = lib.mkForce true;
                """,
                    )
                )
                self.assertEqual(set(snapshot["enabledServices"]), {service, "nginx"})

    def test_ats_can_disable_file_servers(self):
        snapshot = self.snapshot(
            fixture(
                "ats",
                """
          machines.features.fileServers.enable = lib.mkForce false;
        """,
            )
        )
        self.assertEqual(
            set(snapshot["enabledServices"]), ATS - {"rankserver", "stampserver"}
        )
        self.assertFalse({"rankserver", "stampserver"} & set(snapshot["units"]))

    def test_recreation_does_not_require_game_streaming(self):
        snapshot = self.snapshot(
            fixture(
                "personal",
                """
          machines.features.gameStreaming.enable = lib.mkForce false;
        """,
            )
        )
        self.assertTrue(snapshot["features"]["recreation"])
        self.assertEqual(
            set(snapshot["enabledServices"]), PERSONAL - {"sunshine", "sunset"}
        )

    def test_folio_roles_and_structured_ports(self):
        hub = self.snapshot(fixture("ats"))
        spoke = self.snapshot(fixture("personal"))
        self.assertTrue(hub["folioHub"])
        self.assertFalse(hub["folioDesktop"])
        self.assertFalse(spoke["folioHub"])
        self.assertTrue(spoke["folioDesktop"])
        for snapshot in [hub, spoke]:
            for service in snapshot["webServices"]:
                if service["path"] == "#":
                    self.assertIsInstance(service["port"], int)

    def test_agent_ui_requires_a_framework(self):
        result = evaluate(
            fixture(
                "workstation",
                """
          machines.features.agentUi.enable = lib.mkForce true;
          machines.features.agents.frameworks = lib.mkForce [];
        """,
            )
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            "Agent UI requires",
            "\n".join(json.loads(result.stdout)["failedAssertions"]),
        )

    def test_misspelled_job_field_is_rejected(self):
        self.rejected(
            fixture(
                "workstation",
                """
          machines.features.orchestrator.jobs = [{
            name = "probe"; jobShellScript = "/unused";
            timerCfg.OnCalendar = "daily";
            logTag = [ "typo" ];
          }];
        """,
            ),
            "logTag",
        )

    def test_missing_feature_choice_is_rejected(self):
        self.rejected(
            f"""
          {{ lib, ... }}: {{
            imports = [ {NIXOS_DIR}/pc-base.nix ];
            machines.base = {{ nixosState = "{NIXOS_STATE}"; machineType = "x86_linux"; cloudDirs = []; }};
            machines.features = (lib.mapAttrs (_: _: {{ enable = false; }})
              (builtins.removeAttrs (import {NIXOS_DIR}/features/catalog.nix) [ "agentUi" ]))
              // {{ agents.frameworks = []; }};
          }}
        """,
            "machines.features.agentUi.enable",
        )

    def test_false_assertions_are_reported(self):
        configuration = fixture(
            "workstation",
            """
          assertions = [{ assertion = false; message = "profile-contract-probe"; }];
        """,
        )
        result = evaluate(configuration)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            "profile-contract-probe", json.loads(result.stdout)["failedAssertions"]
        )
        with contextlib.redirect_stdout(io.StringIO()):
            ok, _ = eval_config(configuration, "intentional failure")
        self.assertFalse(ok)


if __name__ == "__main__":
    unittest.main(verbosity=2)
