"""
Deployment Screen

Interface for configuring and running deployments.
"""

from __future__ import annotations

import asyncio
from datetime import datetime
from pathlib import Path
from typing import Optional

from textual.app import ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.screen import Screen
from textual.widgets import Button, Header, Footer, Label, Checkbox, Static
from textual.reactive import reactive

from widgets.deployment_list import DeploymentList
from widgets.status_panel import StatusPanel
from widgets.log_viewer import LogViewer
from widgets.confirmation_dialog import ConfirmationDialog
from config import load_app_config, add_deployment_record, DeploymentRecord


class DeploymentConfigPanel(Container):
    """Panel for configuring deployment options."""

    DEFAULT_CSS = """
    DeploymentConfigPanel {
        height: auto;
        border: solid $primary;
        padding: 1;
        margin: 1;
    }

    DeploymentConfigPanel .config-title {
        width: 100%;
        color: $primary;
        text-style: bold;
        padding: 0 0 1 0;
    }

    DeploymentConfigPanel Checkbox {
        padding: 0 1;
    }

    DeploymentConfigPanel .config-row {
        width: 100%;
        height: auto;
        padding: 0 1;
    }
    """

    def compose(self) -> ComposeResult:
        """Compose configuration panel."""
        yield Label("Deployment Targets", classes="config-title")

        yield Checkbox("Infrastructure (Terraform)", True, id="target-infra")
        yield Checkbox("PXE Setup", False, id="target-pxe")
        yield Checkbox("OS Installation", True, id="target-os")
        yield Checkbox("Post-Configuration", True, id="target-post")

        yield Label("\nOptions", classes="config-title")
        yield Checkbox("Plan Only (Dry Run)", False, id="opt-plan-only")
        yield Checkbox("Debug Mode", False, id="opt-debug")

    def get_targets(self) -> list[str]:
        """Get selected deployment targets."""
        targets = []

        if self.query_one("#target-infra", Checkbox).value:
            targets.append("infra")
        if self.query_one("#target-pxe", Checkbox).value:
            targets.append("pxe")
        if self.query_one("#target-os", Checkbox).value:
            targets.append("os")
        if self.query_one("#target-post", Checkbox).value:
            targets.append("post")

        return targets

    def is_plan_only(self) -> bool:
        """Check if plan-only mode is enabled."""
        return self.query_one("#opt-plan-only", Checkbox).value

    def is_debug_mode(self) -> bool:
        """Check if debug mode is enabled."""
        return self.query_one("#opt-debug", Checkbox).value


class DeploymentScreen(Screen):
    """
    Deployment configuration and execution screen.

    Features:
    - VM selection with multi-select
    - Target selection (infra, pxe, os, post)
    - Real-time deployment progress
    - Live log streaming
    - Deployment control (run, stop, cancel)
    """

    BINDINGS = [
        ("r", "run_deployment", "Run"),
        ("p", "plan_deployment", "Plan"),
        ("s", "stop_deployment", "Stop"),
        ("a", "select_all", "Select All"),
        ("A", "deselect_all", "Deselect All"),
        ("q", "back", "Back"),
    ]

    DEFAULT_CSS = """
    DeploymentScreen {
        background: $background;
    }

    DeploymentScreen .deployment-grid {
        layout: grid;
        grid-size: 2 2;
        grid-gutter: 1;
        padding: 1;
        height: 1fr;
    }

    DeploymentScreen .control-panel {
        height: auto;
        padding: 1;
    }

    DeploymentScreen .control-buttons {
        layout: horizontal;
        height: auto;
        padding: 1;
    }

    DeploymentScreen Button {
        margin: 0 1;
    }
    """

    deployment_running = reactive(False)

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.deployment_task: Optional[asyncio.Task] = None

    def compose(self) -> ComposeResult:
        """Compose the deployment screen."""
        yield Header()

        with Container(classes="deployment-grid"):
            # VM selection list
            yield DeploymentList(title="Select VMs to Deploy")

            # Configuration panel
            yield DeploymentConfigPanel()

            # Status panel
            yield StatusPanel(title="Deployment Status")

            # Log viewer
            yield LogViewer(title="Deployment Logs", max_lines=1000)

        # Control buttons
        with Container(classes="control-panel"):
            with Horizontal(classes="control-buttons"):
                yield Button("Run Deployment (r)", id="btn-run", variant="primary")
                yield Button("Plan Only (p)", id="btn-plan")
                yield Button("Stop (s)", id="btn-stop", variant="error", disabled=True)
                yield Button("Select All (a)", id="btn-select-all")
                yield Button("Clear (A)", id="btn-deselect-all")
                yield Button("Back (q)", id="btn-back")

        yield Footer()

    def on_mount(self) -> None:
        """Called when screen is mounted."""
        # Load VMs from configuration
        self._load_vms()

    def _load_vms(self) -> None:
        """Load VMs from configuration files."""
        config = load_app_config()

        try:
            # This would actually load from config files
            # For now, add some example VMs
            vm_list = self.query_one(DeploymentList)

            # Example VMs - in real implementation, load from config
            example_vms = [
                {"name": "web-server-1", "tenant": "production", "os": "ubuntu"},
                {"name": "db-server-1", "tenant": "production", "os": "ubuntu"},
                {"name": "app-server-1", "tenant": "staging", "os": "nixos"},
                {"name": "cache-server-1", "tenant": "staging", "os": "ubuntu"},
            ]

            vm_list.set_vms(example_vms)

        except Exception as e:
            log_viewer = self.query_one(LogViewer)
            log_viewer.add_line(f"Error loading VMs: {e}")

    def action_run_deployment(self) -> None:
        """Run the deployment."""
        vm_list = self.query_one(DeploymentList)
        selected_vms = vm_list.get_selected_vms()

        if not selected_vms:
            log_viewer = self.query_one(LogViewer)
            log_viewer.add_line("Error: No VMs selected for deployment")
            return

        # Show confirmation dialog
        config_panel = self.query_one(DeploymentConfigPanel)
        targets = config_panel.get_targets()

        dialog = ConfirmationDialog(
            title="Confirm Deployment",
            message=f"Deploy to {len(selected_vms)} VM(s) with targets: {', '.join(targets)}?",
            confirm_text="Deploy",
            cancel_text="Cancel",
            confirm_variant="primary",
            data={"vms": selected_vms, "targets": targets}
        )

        self.mount(dialog)

    def action_plan_deployment(self) -> None:
        """Run deployment in plan-only mode."""
        # Similar to run but with plan-only flag
        log_viewer = self.query_one(LogViewer)
        log_viewer.add_line("Plan-only mode not yet implemented")

    def action_stop_deployment(self) -> None:
        """Stop the running deployment."""
        if self.deployment_task and not self.deployment_task.done():
            self.deployment_task.cancel()
            log_viewer = self.query_one(LogViewer)
            log_viewer.add_line("Deployment stopped by user")

    def action_select_all(self) -> None:
        """Select all VMs."""
        vm_list = self.query_one(DeploymentList)
        vm_list.select_all()

    def action_deselect_all(self) -> None:
        """Deselect all VMs."""
        vm_list = self.query_one(DeploymentList)
        vm_list.deselect_all()

    def action_back(self) -> None:
        """Go back to dashboard."""
        self.app.pop_screen()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        button_id = event.button.id

        if button_id == "btn-run":
            self.action_run_deployment()
        elif button_id == "btn-plan":
            self.action_plan_deployment()
        elif button_id == "btn-stop":
            self.action_stop_deployment()
        elif button_id == "btn-select-all":
            self.action_select_all()
        elif button_id == "btn-deselect-all":
            self.action_deselect_all()
        elif button_id == "btn-back":
            self.action_back()

    def on_confirmation_dialog_confirmed(self, message: ConfirmationDialog.Confirmed) -> None:
        """Handle deployment confirmation."""
        vms = message.data.get("vms", [])
        targets = message.data.get("targets", [])

        # Start deployment
        self._start_deployment(vms, targets)

    async def _start_deployment(self, vms: list[str], targets: list[str]) -> None:
        """Start the deployment process."""
        log_viewer = self.query_one(LogViewer)
        status_panel = self.query_one(StatusPanel)

        log_viewer.clear()
        log_viewer.add_line(f"Starting deployment to {len(vms)} VM(s)")
        log_viewer.add_line(f"Targets: {', '.join(targets)}")
        log_viewer.add_line("-" * 50)

        status_panel.start_deployment(len(vms))

        # Disable run button, enable stop button
        self.query_one("#btn-run", Button).disabled = True
        self.query_one("#btn-stop", Button).disabled = False

        start_time = datetime.now()
        errors = []

        try:
            # Simulate deployment (in real implementation, call provision.py)
            for idx, vm in enumerate(vms, 1):
                log_viewer.add_line(f"\n[{idx}/{len(vms)}] Deploying {vm}...")
                status_panel.set_current_vm(vm)

                # Simulate work
                await asyncio.sleep(2)

                log_viewer.add_line(f"✓ {vm} deployed successfully")
                status_panel.complete_vm(vm, success=True)

            # Record deployment
            duration = (datetime.now() - start_time).total_seconds()
            record = DeploymentRecord(
                timestamp=start_time.isoformat(),
                vms=vms,
                targets=targets,
                status="success",
                duration_seconds=duration,
                errors=errors,
            )
            add_deployment_record(record)

            log_viewer.add_line("\n" + "=" * 50)
            log_viewer.add_line("Deployment completed successfully!")

        except Exception as e:
            log_viewer.add_line(f"\nError: {e}")
            errors.append(str(e))

        finally:
            # Re-enable buttons
            self.query_one("#btn-run", Button).disabled = False
            self.query_one("#btn-stop", Button).disabled = True
