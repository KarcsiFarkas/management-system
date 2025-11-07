"""
Async utilities for running commands and streaming output.
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path
from typing import AsyncIterator, Callable, Optional


class CommandOutput:
    """Stores command output and metadata."""

    def __init__(self):
        self.lines: list[str] = []
        self.return_code: Optional[int] = None
        self.completed = False
        self.error: Optional[str] = None


async def run_async_command(
    *cmd: str,
    cwd: Optional[Path] = None,
    env: Optional[dict[str, str]] = None,
    timeout: Optional[float] = None,
) -> tuple[int, str, str]:
    """
    Run a command asynchronously and capture output.

    Args:
        *cmd: Command and arguments
        cwd: Working directory
        env: Environment variables
        timeout: Timeout in seconds

    Returns:
        Tuple of (return_code, stdout, stderr)
    """
    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            cwd=str(cwd) if cwd else None,
            env=env,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        stdout_bytes, stderr_bytes = await asyncio.wait_for(
            proc.communicate(), timeout=timeout
        )

        stdout = stdout_bytes.decode("utf-8", errors="replace")
        stderr = stderr_bytes.decode("utf-8", errors="replace")

        return (proc.returncode or 0, stdout, stderr)

    except asyncio.TimeoutError:
        if proc:
            proc.kill()
            await proc.wait()
        return (-1, "", "Command timed out")
    except Exception as e:
        return (-1, "", str(e))


async def stream_command_output(
    *cmd: str,
    cwd: Optional[Path] = None,
    env: Optional[dict[str, str]] = None,
    callback: Optional[Callable[[str], None]] = None,
) -> AsyncIterator[str]:
    """
    Stream command output line by line.

    Args:
        *cmd: Command and arguments
        cwd: Working directory
        env: Environment variables
        callback: Optional callback for each line

    Yields:
        Output lines as they arrive
    """
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        cwd=str(cwd) if cwd else None,
        env=env,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
    )

    assert proc.stdout

    async for line_bytes in proc.stdout:
        line = line_bytes.decode("utf-8", errors="replace").rstrip()

        if callback:
            callback(line)

        yield line

    await proc.wait()


class AsyncCommandRunner:
    """Manages async command execution with output streaming."""

    def __init__(self):
        self.running_commands: dict[str, asyncio.Task] = {}
        self.command_outputs: dict[str, CommandOutput] = {}

    async def run_command(
        self,
        command_id: str,
        *cmd: str,
        cwd: Optional[Path] = None,
        env: Optional[dict[str, str]] = None,
    ) -> CommandOutput:
        """
        Run a command and store its output.

        Args:
            command_id: Unique identifier for this command
            *cmd: Command and arguments
            cwd: Working directory
            env: Environment variables

        Returns:
            CommandOutput object that gets updated as command runs
        """
        output = CommandOutput()
        self.command_outputs[command_id] = output

        async def _run():
            try:
                proc = await asyncio.create_subprocess_exec(
                    *cmd,
                    cwd=str(cwd) if cwd else None,
                    env=env,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.STDOUT,
                )

                assert proc.stdout

                async for line_bytes in proc.stdout:
                    line = line_bytes.decode("utf-8", errors="replace").rstrip()
                    output.lines.append(line)

                output.return_code = await proc.wait()
                output.completed = True

            except Exception as e:
                output.error = str(e)
                output.completed = True
                output.return_code = -1

        task = asyncio.create_task(_run())
        self.running_commands[command_id] = task

        return output

    def get_output(self, command_id: str) -> Optional[CommandOutput]:
        """Get output for a command."""
        return self.command_outputs.get(command_id)

    def is_running(self, command_id: str) -> bool:
        """Check if command is still running."""
        if command_id not in self.running_commands:
            return False

        task = self.running_commands[command_id]
        return not task.done()

    async def wait_for_command(self, command_id: str) -> Optional[CommandOutput]:
        """Wait for command to complete and return output."""
        if command_id not in self.running_commands:
            return None

        task = self.running_commands[command_id]
        await task

        return self.command_outputs.get(command_id)

    def cancel_command(self, command_id: str) -> bool:
        """Cancel a running command."""
        if command_id not in self.running_commands:
            return False

        task = self.running_commands[command_id]
        if not task.done():
            task.cancel()
            return True

        return False

    def cleanup_command(self, command_id: str) -> None:
        """Remove command from tracking."""
        self.running_commands.pop(command_id, None)
        self.command_outputs.pop(command_id, None)


# Global command runner instance
command_runner = AsyncCommandRunner()
