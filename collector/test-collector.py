#!/usr/bin/env python3
"""Collector contract and publication failure checks; no live service calls."""

import copy
import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("collector", Path(__file__).with_name("collect-quota.py"))
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)
NOW = 1800000000


def limits():
    return {"rateLimitsByLimitId": {"codex": {
        "primary": {"usedPercent": 65, "windowDurationMins": 300, "resetsAt": NOW + 10800},
        "secondary": {"usedPercent": 35, "windowDurationMins": 10080, "resetsAt": NOW + 390600},
    }}}


class CollectorTests(unittest.TestCase):
    def test_maps_windows_by_duration_even_when_reversed(self):
        result = limits()
        bucket = result["rateLimitsByLimitId"]["codex"]
        bucket["primary"], bucket["secondary"] = bucket["secondary"], bucket["primary"]
        snapshot = collector.snapshot_from_limits(result, NOW)
        self.assertEqual(snapshot["session"], {"quotaRemaining": 0.35, "durationSeconds": 18000, "resetsAt": NOW + 10800})
        self.assertEqual(snapshot["weekly"]["quotaRemaining"], 0.65)
        self.assertEqual(snapshot["observedAt"], NOW)

    def test_missing_reset_is_unknown_not_zero_quota(self):
        result = limits()
        result["rateLimitsByLimitId"]["codex"]["primary"]["resetsAt"] = None
        snapshot = collector.snapshot_from_limits(result, NOW)
        self.assertIsNone(snapshot["session"])
        self.assertIsNotNone(snapshot["weekly"])

    def test_unknown_durations_do_not_get_mislabeled(self):
        result = limits()
        bucket = result["rateLimitsByLimitId"]["codex"]
        bucket["primary"]["windowDurationMins"] = 15
        bucket["secondary"] = None
        with self.assertRaises(ValueError):
            collector.snapshot_from_limits(result, NOW)

    def test_never_uses_an_unrelated_bucket(self):
        result = limits()
        result["rateLimitsByLimitId"]["other"] = result["rateLimitsByLimitId"].pop("codex")
        with self.assertRaises(ValueError):
            collector.snapshot_from_limits(result, NOW)

    def test_legacy_bucket_without_id_is_supported(self):
        result = {"rateLimits": limits()["rateLimitsByLimitId"]["codex"]}
        self.assertEqual(collector.snapshot_from_limits(result, NOW)["session"]["quotaRemaining"], 0.35)

    def test_millisecond_reset_and_invalid_usage_fail(self):
        for field, value in [("resetsAt", (NOW + 10800) * 1000), ("usedPercent", float("nan")), ("usedPercent", True), ("usedPercent", -1)]:
            with self.subTest(field=field, value=value):
                result = limits()
                result["rateLimitsByLimitId"]["codex"]["primary"][field] = value
                with self.assertRaises(ValueError):
                    collector.snapshot_from_limits(result, NOW)

    def test_over_quota_clamps_to_zero(self):
        result = limits()
        result["rateLimitsByLimitId"]["codex"]["primary"]["usedPercent"] = 110
        self.assertEqual(collector.snapshot_from_limits(result, NOW)["session"]["quotaRemaining"], 0)

    def test_anonymous_read_is_required_for_success(self):
        snapshot = collector.snapshot_from_limits(limits(), NOW)
        config = {"namespace": "test", "path": "data/entry", "key": "write-secret"}
        with patch.object(collector, "request_json", side_effect=[{}, {}, snapshot]) as request:
            collector.publish(config, snapshot)
            self.assertEqual(request.call_args.args, ("https://mantledb.sh/v2/test/data/entry",))
            self.assertEqual(request.call_args.kwargs, {})
        wrong = copy.deepcopy(snapshot)
        wrong["observedAt"] -= 300
        with patch.object(collector, "request_json", side_effect=[{}, {}, wrong]):
            with self.assertRaises(RuntimeError):
                collector.publish(config, snapshot)


if __name__ == "__main__":
    unittest.main()
