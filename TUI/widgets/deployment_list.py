"""
Deployment List Widget

Displays available VMs/hosts for deployment with multi-selection support.
"""

from __future__ import annotations

from typing import Optional

from textual.app import ComposeResult
from textual.containers import VerticalScroll
from textual.widgets import ListItem, ListView, Label, Checkbox
from textual.reactive import reactive


class DeploymentListItem(ListItem):
    """A single deployment item with checkbox."""

    def __init__(
        self,
        vm_name: str,
        tenant: str = "default",
        os_type: str = "ubuntu",
        selected: bool = False,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.vm_name = vm_name
        self.tenant = tenant
        self.os_type = os_type
        self._selected = selected

    def compose(self) -> ComposeResult:
        """Compose the list item."""
        checkbox = Checkbox("", self._selected, id=f"cb_{self.vm_name}")
        label = Label(f"{self.vm_name} ({self.os_type}, {self.tenant})")
        yield checkbox
        yield label

    @property
    def selected(self) -> bool:
        """Check if item is selected."""
        try:
            cb = self.query_one(f"#cb_{self.vm_name}", Checkbox)
            return cb.value
        except Exception:
            return self._selected

    def toggle_selection(self) -> None:
        """Toggle selection state."""
        try:
            cb = self.query_one(f"#cb_{self.vm_name}", Checkbox)
            cb.toggle()
            self._selected = cb.value
        except Exception:
            self._selected = not self._selected


class DeploymentList(VerticalScroll):
    """
    List of VMs/hosts available for deployment.

    Features:
    - Multi-selection with checkboxes
    - Filtering by name/tenant/OS
    - Select all/none
    - Keyboard navigation (vim motions)
    """

    DEFAULT_CSS = """
    DeploymentList {
        border: solid $primary;
        background: $surface;
        height: 1fr;
        padding: 1;
    }

    DeploymentList .list-header {
        color: $primary;
        text-style: bold;
        padding: 0 0 1 0;
    }

    DeploymentListItem {
        layout: horizontal;
        height: auto;
        padding: 0 1;
    }

    DeploymentListItem:hover {
        background: $panel;
    }

    DeploymentListItem Checkbox {
        width: auto;
    }

    DeploymentListItem Label {
        width: 1fr;
        padding: 0 1;
    }
    """

    filter_text = reactive("")

    def __init__(
        self,
        *,
        title: str = "Select VMs for Deployment",
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.title = title
        self.items: list[DeploymentListItem] = []
        self.filtered_items: list[DeploymentListItem] = []
        self.current_index = 0

    def compose(self) -> ComposeResult:
        """Compose the deployment list."""
        yield Label(self.title, classes="list-header")

    def add_vm(
        self,
        vm_name: str,
        tenant: str = "default",
        os_type: str = "ubuntu",
        selected: bool = False,
    ) -> None:
        """Add a VM to the list."""
        item = DeploymentListItem(
            vm_name=vm_name,
            tenant=tenant,
            os_type=os_type,
            selected=selected,
        )
        self.items.append(item)
        self._refresh_display()

    def set_vms(self, vms: list[dict[str, str]]) -> None:
        """Set the VM list from a list of dicts."""
        self.items.clear()

        for vm in vms:
            item = DeploymentListItem(
                vm_name=vm.get("name", "unknown"),
                tenant=vm.get("tenant", "default"),
                os_type=vm.get("os", "ubuntu"),
                selected=vm.get("selected", False),
            )
            self.items.append(item)

        self._refresh_display()

    def get_selected_vms(self) -> list[str]:
        """Get list of selected VM names."""
        return [item.vm_name for item in self.items if item.selected]

    def select_all(self) -> None:
        """Select all VMs."""
        for item in self.items:
            item._selected = True
            try:
                cb = item.query_one(f"#cb_{item.vm_name}", Checkbox)
                cb.value = True
            except Exception:
                pass

    def deselect_all(self) -> None:
        """Deselect all VMs."""
        for item in self.items:
            item._selected = False
            try:
                cb = item.query_one(f"#cb_{item.vm_name}", Checkbox)
                cb.value = False
            except Exception:
                pass

    def toggle_current(self) -> None:
        """Toggle selection of current item."""
        if 0 <= self.current_index < len(self.filtered_items):
            self.filtered_items[self.current_index].toggle_selection()

    def set_filter(self, filter_text: str) -> None:
        """Set filter text."""
        self.filter_text = filter_text.lower()
        self._refresh_display()

    def _refresh_display(self) -> None:
        """Refresh the display based on current filter."""
        # Clear current display
        try:
            for item in self.filtered_items:
                item.remove()
        except Exception:
            pass

        self.filtered_items.clear()

        # Apply filter and add items
        for item in self.items:
            if self.filter_text:
                if (
                    self.filter_text not in item.vm_name.lower()
                    and self.filter_text not in item.tenant.lower()
                    and self.filter_text not in item.os_type.lower()
                ):
                    continue

            self.filtered_items.append(item)
            self.mount(item)

    def clear(self) -> None:
        """Clear all items."""
        for item in self.items:
            item.remove()

        self.items.clear()
        self.filtered_items.clear()
        self.current_index = 0

    def get_vm_count(self) -> tuple[int, int]:
        """Get (selected_count, total_count) tuple."""
        selected = len(self.get_selected_vms())
        total = len(self.items)
        return (selected, total)
