"""Software-only controller protocol model for CD0-ABYSS Sprint 03B.

This is a host-side functional model, not MCU firmware or a hardware specification.
All numeric limits are protocol-field limits unless explicitly validated below.
"""
from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
import struct


SYNC = b"\xC3\x3C"
PROTOCOL_VERSION = 1
MAX_PAYLOAD = 64


class ProtocolError(ValueError):
    """Raised when a wire frame is malformed or fails its CRC."""


class Mode(IntEnum):
    CW = 0
    LFM = 1


class Command(IntEnum):
    SET_MODE = 0x01
    SET_START_FREQ = 0x02
    SET_STOP_FREQ = 0x03
    SET_SWEEP_RATE = 0x04
    SET_AMPLITUDE = 0x05
    START = 0x06
    STOP = 0x07
    STATUS = 0x08
    FAULT_CLEAR = 0x09


class Result(IntEnum):
    OK = 0
    INVALID_ARGUMENT = 1
    INVALID_STATE = 2
    UNKNOWN_COMMAND = 3


@dataclass(frozen=True)
class Frame:
    sequence: int
    command: int
    payload: bytes = b""
    version: int = PROTOCOL_VERSION


def crc16_ccitt_false(data: bytes) -> int:
    """CRC-16/CCITT-FALSE: poly=0x1021, init=0xFFFF, no reflection/xorout."""
    crc = 0xFFFF
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def encode_frame(frame: Frame) -> bytes:
    if not 0 <= frame.sequence <= 0xFF:
        raise ValueError("sequence must fit in uint8")
    if not 0 <= int(frame.command) <= 0xFF:
        raise ValueError("command must fit in uint8")
    if len(frame.payload) > MAX_PAYLOAD:
        raise ValueError("payload exceeds MAX_PAYLOAD")
    body = bytes((frame.version, frame.sequence, int(frame.command), len(frame.payload))) + frame.payload
    crc = crc16_ccitt_false(body)
    return SYNC + body + struct.pack("<H", crc)


def decode_frame(packet: bytes) -> Frame:
    if len(packet) < 8 or packet[:2] != SYNC:
        raise ProtocolError("bad sync or frame too short")
    version, sequence, command, length = packet[2:6]
    if version != PROTOCOL_VERSION:
        raise ProtocolError(f"unsupported protocol version: {version}")
    if length > MAX_PAYLOAD or len(packet) != 8 + length:
        raise ProtocolError("invalid payload length")
    body = packet[2:-2]
    received_crc = struct.unpack("<H", packet[-2:])[0]
    if crc16_ccitt_false(body) != received_crc:
        raise ProtocolError("CRC mismatch")
    return Frame(sequence=sequence, command=command, payload=packet[6:-2], version=version)


class FrameParser:
    """Incremental stream parser suitable for fragmented UART byte streams."""

    def __init__(self) -> None:
        self._buffer = bytearray()

    def feed(self, data: bytes) -> list[Frame]:
        self._buffer.extend(data)
        frames: list[Frame] = []
        while True:
            sync_at = self._buffer.find(SYNC)
            if sync_at < 0:
                # Keep a trailing first sync byte in case the next chunk completes it.
                keep = 1 if self._buffer.endswith(SYNC[:1]) else 0
                self._buffer[:] = self._buffer[-keep:] if keep else b""
                break
            if sync_at:
                del self._buffer[:sync_at]
            if len(self._buffer) < 6:
                break
            length = self._buffer[5]
            if length > MAX_PAYLOAD:
                del self._buffer[0]
                continue
            frame_size = 8 + length
            if len(self._buffer) < frame_size:
                break
            candidate = bytes(self._buffer[:frame_size])
            try:
                frames.append(decode_frame(candidate))
                del self._buffer[:frame_size]
            except ProtocolError:
                # Drop one byte and search again, allowing recovery after noise/corruption.
                del self._buffer[0]
        return frames


@dataclass
class ControllerConfig:
    mode: Mode = Mode.CW
    start_frequency_hz: int = 0
    stop_frequency_hz: int = 0
    sweep_rate_hz_per_s: int = 0
    amplitude_permille: int = 0


class ControllerModel:
    """Deterministic controller state machine for protocol-level tests."""

    def __init__(self) -> None:
        self.config = ControllerConfig()
        self.running = False
        self.fault_code = 0

    def reset(self) -> None:
        self.config = ControllerConfig()
        self.running = False
        self.fault_code = 0

    def raise_fault(self, fault_code: int) -> None:
        if not 1 <= fault_code <= 0xFFFF:
            raise ValueError("fault code must be in range 1..65535")
        self.fault_code = fault_code
        self.running = False

    def _ack(self, request: Frame, result: Result, extra: bytes = b"") -> Frame:
        return Frame(request.sequence, (int(request.command) | 0x80) & 0xFF,
                     bytes((int(result),)) + extra)

    def handle(self, request: Frame) -> Frame:
        try:
            command = Command(request.command)
        except ValueError:
            return self._ack(request, Result.UNKNOWN_COMMAND)

        if command == Command.STATUS:
            status = struct.pack(
                "<BBIIIHH",
                int(self.running),
                int(self.config.mode),
                self.config.start_frequency_hz,
                self.config.stop_frequency_hz,
                self.config.sweep_rate_hz_per_s,
                self.config.amplitude_permille,
                self.fault_code,
            )
            return self._ack(request, Result.OK, status)

        if command == Command.FAULT_CLEAR:
            if self.running:
                return self._ack(request, Result.INVALID_STATE)
            self.fault_code = 0
            return self._ack(request, Result.OK)

        if self.running and command not in (Command.STOP,):
            return self._ack(request, Result.INVALID_STATE)

        payload = request.payload
        try:
            if command == Command.SET_MODE:
                if len(payload) != 1:
                    raise ValueError
                self.config.mode = Mode(payload[0])
            elif command in (Command.SET_START_FREQ, Command.SET_STOP_FREQ,
                             Command.SET_SWEEP_RATE):
                if len(payload) != 4:
                    raise ValueError
                value = struct.unpack("<I", payload)[0]
                if value == 0:
                    raise ValueError
                if command == Command.SET_START_FREQ:
                    self.config.start_frequency_hz = value
                elif command == Command.SET_STOP_FREQ:
                    self.config.stop_frequency_hz = value
                else:
                    self.config.sweep_rate_hz_per_s = value
            elif command == Command.SET_AMPLITUDE:
                if len(payload) != 2:
                    raise ValueError
                value = struct.unpack("<H", payload)[0]
                if value > 1000:
                    raise ValueError
                self.config.amplitude_permille = value
            elif command == Command.START:
                if payload or self.fault_code:
                    return self._ack(request, Result.INVALID_STATE)
                if self.config.start_frequency_hz == 0:
                    raise ValueError
                if self.config.mode == Mode.LFM and (
                    self.config.stop_frequency_hz <= self.config.start_frequency_hz
                    or self.config.sweep_rate_hz_per_s == 0
                ):
                    raise ValueError
                self.running = True
            elif command == Command.STOP:
                if payload:
                    raise ValueError
                self.running = False
            else:
                return self._ack(request, Result.UNKNOWN_COMMAND)
        except (ValueError, struct.error):
            return self._ack(request, Result.INVALID_ARGUMENT)

        return self._ack(request, Result.OK)
