import asyncio
from dataclasses import dataclass
from typing import Optional, List

from bleak import BleakScanner, BleakClient


@dataclass
class EEGPacket:
    index: int
    ch1: List[int]
    ch2: List[int]


class NeocoreClient:
    SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    WRITE_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    NOTIFY_UUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

    # Feature IDs
    CORE_FEATURE = 0x00
    SENSOR_CFG_FEATURE = 0x01
    SENSOR_STREAM_FEATURE = 0x02
    BATTERY_FEATURE = 0x03

    # PDU Types
    PDU_COMMAND = 0
    PDU_NOTIFICATION = 1
    PDU_RESPONSE = 2
    PDU_ERROR = 3

    # Command IDs
    CMD_GET_SERIAL = 0x01
    CMD_GET_BATTERY = 0x00
    CMD_STREAM_CTRL = 0x00
    CMD_TEST_SIGNAL_CTRL = 0x01

    EEG_PACKET_TYPE = 0x04

    TARGET_NAMES = ["QCC5181", "QCC5181-LE", "NEOCORE"]

    def __init__(self):
        self.client: Optional[BleakClient] = None
        self.serial_number: Optional[str] = None
        self.battery_level: Optional[int] = None

    async def scan_and_connect(self):
        print("Scanning for devices…")
        devices = await BleakScanner.discover()
        target = None
        for d in devices:
            if any(name in (d.name or "") for name in self.TARGET_NAMES):
                target = d
                break
        if not target:
            raise RuntimeError("Neocore device not found")

        print(f"Connecting to {target.name} ({target.address})")
        self.client = BleakClient(target)
        await self.client.connect()
        await self.client.start_notify(self.NOTIFY_UUID, self.handle_notification)

        # Request serial number and battery level
        await asyncio.sleep(0.5)
        await self.send_command(self.CORE_FEATURE, self.PDU_COMMAND, self.CMD_GET_SERIAL)
        await asyncio.sleep(0.5)
        await self.send_command(self.BATTERY_FEATURE, self.PDU_COMMAND, self.CMD_GET_BATTERY)

    async def disconnect(self):
        if self.client and self.client.is_connected:
            await self.client.stop_notify(self.NOTIFY_UUID)
            await self.client.disconnect()

    async def send_command(self, feature_id: int, pdu_type: int, pdu_id: int, data: bytes = b""):
        if not self.client:
            raise RuntimeError("Not connected")
        cmd_id = ((feature_id << 9) | (pdu_type << 7)) | pdu_id
        payload = cmd_id.to_bytes(2, "big") + data
        print(f"Sending command 0x{cmd_id:04X} -> {payload.hex()}")
        await self.client.write_gatt_char(self.WRITE_UUID, payload, response=True)

    async def start_streaming(self, use_test_signal: bool = False):
        if use_test_signal:
            await self.send_command(self.SENSOR_CFG_FEATURE, self.PDU_COMMAND, self.CMD_TEST_SIGNAL_CTRL, b"\x01")
            await asyncio.sleep(0.5)
        await self.send_command(self.SENSOR_CFG_FEATURE, self.PDU_COMMAND, self.CMD_STREAM_CTRL, b"\x01")

    async def stop_streaming(self):
        await self.send_command(self.SENSOR_CFG_FEATURE, self.PDU_COMMAND, self.CMD_STREAM_CTRL, b"\x00")
        await self.send_command(self.SENSOR_CFG_FEATURE, self.PDU_COMMAND, self.CMD_TEST_SIGNAL_CTRL, b"\x00")

    # Notification handler
    def handle_notification(self, sender: int, data: bytearray):
        if not data:
            return
        packet_type = data[0]
        if packet_type == self.EEG_PACKET_TYPE:
            pkt = self.parse_eeg_packet(data)
            if pkt:
                print(f"EEG idx={pkt.index} ch1={len(pkt.ch1)} samples ch2={len(pkt.ch2)} samples")
        else:
            self.parse_response(data)

    def parse_response(self, data: bytes):
        if len(data) < 2:
            return
        command_id = (data[0] << 8) | data[1]
        feature_id = command_id >> 9
        pdu_type = (command_id >> 7) & 0x03
        pdu_id = command_id & 0x7F
        payload = data[2:]
        print(f"Response feat={feature_id} type={pdu_type} id={pdu_id} payload={payload.hex()}")
        if pdu_type == self.PDU_RESPONSE:
            if feature_id == self.CORE_FEATURE and pdu_id == self.CMD_GET_SERIAL:
                try:
                    self.serial_number = payload.decode()
                except UnicodeDecodeError:
                    self.serial_number = payload.hex()
                print("Serial:", self.serial_number)
            if feature_id == self.BATTERY_FEATURE and pdu_id == self.CMD_GET_BATTERY and payload:
                self.battery_level = payload[0]
                print("Battery:", self.battery_level)

    def parse_eeg_packet(self, data: bytes) -> Optional[EEGPacket]:
        if len(data) < 4:
            return None
        length = data[1]
        index = int.from_bytes(data[2:4], "little")
        ch1 = []
        ch2 = []
        payload = data[4:]
        for i in range(0, len(payload), 8):
            if i + 8 <= len(payload):
                ch1.append(int.from_bytes(payload[i:i+4], "little", signed=True))
                ch2.append(int.from_bytes(payload[i+4:i+8], "little", signed=True))
        return EEGPacket(index=index, ch1=ch1, ch2=ch2)


async def main():
    client = NeocoreClient()
    await client.scan_and_connect()
    await client.start_streaming(use_test_signal=True)
    try:
        await asyncio.sleep(10)
    finally:
        await client.stop_streaming()
        await client.disconnect()


if __name__ == "__main__":
    asyncio.run(main())
