import struct
import unittest

from controller_protocol import (
    Command, ControllerModel, Frame, FrameParser, Mode, ProtocolError,
    Result, crc16_ccitt_false, decode_frame, encode_frame,
)


class FrameTests(unittest.TestCase):
    def test_crc_reference_vector(self):
        self.assertEqual(crc16_ccitt_false(b"123456789"), 0x29B1)

    def test_round_trip(self):
        frame = Frame(sequence=17, command=Command.SET_START_FREQ,
                      payload=struct.pack("<I", 24000))
        self.assertEqual(decode_frame(encode_frame(frame)), frame)

    def test_incremental_fragmented_stream(self):
        packet = encode_frame(Frame(4, Command.START))
        parser = FrameParser()
        self.assertEqual(parser.feed(packet[:3]), [])
        self.assertEqual(parser.feed(packet[3:6]), [])
        self.assertEqual(parser.feed(packet[6:]), [Frame(4, Command.START)])

    def test_noise_and_corrupt_frame_recovery(self):
        parser = FrameParser()
        good = encode_frame(Frame(9, Command.STATUS))
        bad = bytearray(encode_frame(Frame(8, Command.START)))
        bad[-1] ^= 0x80
        self.assertEqual(parser.feed(b"noise" + bytes(bad) + good),
                         [Frame(9, Command.STATUS)])

    def test_reject_bad_sync_and_crc(self):
        packet = bytearray(encode_frame(Frame(1, Command.STOP)))
        packet[-1] ^= 1
        with self.assertRaises(ProtocolError):
            decode_frame(bytes(packet))
        with self.assertRaises(ProtocolError):
            decode_frame(b"\x00" * 8)

    def test_reject_wrong_length_and_version(self):
        packet = bytearray(encode_frame(Frame(1, Command.STOP)))
        packet[5] = 2
        with self.assertRaises(ProtocolError):
            decode_frame(bytes(packet))
        packet = bytearray(encode_frame(Frame(1, Command.STOP)))
        packet[2] = 2
        with self.assertRaises(ProtocolError):
            decode_frame(bytes(packet))


class ControllerTests(unittest.TestCase):
    def setUp(self):
        self.controller = ControllerModel()

    def send(self, command, payload=b"", sequence=1):
        return self.controller.handle(Frame(sequence, command, payload))

    def result(self, response):
        return Result(response.payload[0])

    def test_cw_configuration_start_stop(self):
        self.assertEqual(self.result(self.send(
            Command.SET_START_FREQ, struct.pack("<I", 30000))), Result.OK)
        self.assertEqual(self.result(self.send(
            Command.SET_AMPLITUDE, struct.pack("<H", 500))), Result.OK)
        self.assertEqual(self.result(self.send(Command.START)), Result.OK)
        self.assertTrue(self.controller.running)
        self.assertEqual(self.result(self.send(Command.SET_START_FREQ,
                                                struct.pack("<I", 40000))), Result.INVALID_STATE)
        self.assertEqual(self.result(self.send(Command.STOP)), Result.OK)
        self.assertFalse(self.controller.running)

    def test_lfm_requires_ordered_frequencies_and_sweep_rate(self):
        self.assertEqual(self.result(self.send(Command.SET_MODE, bytes([Mode.LFM]))), Result.OK)
        self.assertEqual(self.result(self.send(
            Command.SET_START_FREQ, struct.pack("<I", 40000))), Result.OK)
        self.assertEqual(self.result(self.send(
            Command.SET_STOP_FREQ, struct.pack("<I", 30000))), Result.OK)
        self.assertEqual(self.result(self.send(Command.START)), Result.INVALID_ARGUMENT)
        self.assertEqual(self.result(self.send(
            Command.SET_STOP_FREQ, struct.pack("<I", 60000))), Result.OK)
        self.assertEqual(self.result(self.send(
            Command.SET_SWEEP_RATE, struct.pack("<I", 1000))), Result.OK)
        self.assertEqual(self.result(self.send(Command.START)), Result.OK)

    def test_argument_validation(self):
        self.assertEqual(self.result(self.send(Command.SET_MODE, b"\x05")),
                         Result.INVALID_ARGUMENT)
        self.assertEqual(self.result(self.send(Command.SET_AMPLITUDE,
                                                struct.pack("<H", 1001))),
                         Result.INVALID_ARGUMENT)
        self.assertEqual(self.result(self.send(Command.SET_START_FREQ,
                                                struct.pack("<I", 0))),
                         Result.INVALID_ARGUMENT)
        self.assertEqual(self.result(self.send(Command.SET_MODE, b"")),
                         Result.INVALID_ARGUMENT)

    def test_fault_stops_output_and_requires_clear(self):
        self.controller.raise_fault(7)
        self.assertFalse(self.controller.running)
        self.assertEqual(self.result(self.send(Command.START)), Result.INVALID_STATE)
        self.assertEqual(self.result(self.send(Command.FAULT_CLEAR)), Result.OK)
        self.assertEqual(self.controller.fault_code, 0)

    def test_status_and_unknown_command(self):
        response = self.send(Command.STATUS, sequence=33)
        self.assertEqual(response.sequence, 33)
        self.assertEqual(self.result(response), Result.OK)
        self.assertEqual(len(response.payload), 1 + struct.calcsize("<BBIIIHH"))
        self.assertEqual(self.result(self.send(0x70)), Result.UNKNOWN_COMMAND)

    def test_reset_returns_safe_idle_defaults(self):
        self.controller.raise_fault(3)
        self.controller.reset()
        self.assertFalse(self.controller.running)
        self.assertEqual(self.controller.fault_code, 0)
        self.assertEqual(self.controller.config.start_frequency_hz, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
