import contextlib
import importlib.util
import io
import json
from pathlib import Path
import unittest
from unittest import mock


MODULE_PATH = Path(__file__).resolve().parents[1] / "yazelix_input_source_context.py"
SPEC = importlib.util.spec_from_file_location("yazelix_input_source_context", MODULE_PATH)
CONTEXT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONTEXT)


class ActivePaneContextTest(unittest.TestCase):
    def run_helper(self, active_tab_title, mode, panes):
        candidate = {
            "session_id": "yzx-test",
            "zellij_session_name": "test-session",
            "_pane_id": "5",
            "_context": {"mode": mode},
        }
        stdout = io.StringIO()

        with contextlib.ExitStack() as stack:
            stack.enter_context(
                mock.patch.object(CONTEXT, "load_candidates", return_value=[candidate])
            )
            stack.enter_context(
                mock.patch.object(CONTEXT, "zellij_servers", return_value={})
            )
            stack.enter_context(
                mock.patch.object(CONTEXT, "query_panes", return_value=panes)
            )
            stack.enter_context(
                mock.patch.object(
                    CONTEXT.sys,
                    "argv",
                    ["helper", "com.mitchellh.ghostty", "", active_tab_title, ""],
                )
            )
            stack.enter_context(contextlib.redirect_stdout(stdout))
            self.assertEqual(CONTEXT.main(), 0)

        return json.loads(stdout.getvalue())

    def test_floating_panel_over_sidebar_does_not_force_english(self):
        state = self.run_helper(
            "test-session | sidebar",
            "normal",
            [
                {
                    "id": "6",
                    "title": "sidebar",
                    "terminal_command": "yazi",
                    "is_plugin": False,
                    "is_focused": True,
                    "is_floating": False,
                    "exited": False,
                },
                {
                    "id": "plugin_7",
                    "title": "panel",
                    "is_plugin": True,
                    "is_focused": True,
                    "is_floating": True,
                    "exited": False,
                },
            ],
        )

        self.assertEqual(state["focus"], "other")
        self.assertFalse(state["keep_english"])

    def test_sidebar_without_overlay_still_forces_english(self):
        state = self.run_helper(
            "test-session | sidebar",
            "normal",
            [
                {
                    "id": "6",
                    "title": "sidebar",
                    "terminal_command": "yazi",
                    "is_plugin": False,
                    "is_focused": True,
                    "is_floating": False,
                    "exited": False,
                }
            ],
        )

        self.assertEqual(state["focus"], "sidebar")
        self.assertTrue(state["keep_english"])


if __name__ == "__main__":
    unittest.main()
