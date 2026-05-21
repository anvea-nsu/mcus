import serial
import struct
import time


def crc16(data: bytes) -> bytes:
    crc = 0xFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if crc & 1 else crc >> 1
    return struct.pack('<H', crc)


def send_frame(ser, frame, desc=""):
    crc = crc16(bytes(frame))
    full = bytes(frame) + crc
    print(f"\n--- {desc} ---")
    print(f"TX: {full.hex(' ').upper()}")
    ser.write(full)
    time.sleep(0.3)
    if ser.in_waiting:
        resp = ser.read(ser.in_waiting)
        print(f"RX: {resp.hex(' ').upper()}")
    else:
        print("RX: (нет ответа)")


PORT = 'COM11'
ser = serial.Serial(PORT, baudrate=9600, timeout=0.5)

# --- Тест 1: Неверный Slave ID (0x02) ---
send_frame(ser, [0x02, 0x05, 0x00, 0x00, 0xFF, 0x00], "Неверный Slave ID (0x02)")

# --- Тест 2: Неверный адрес катушки (0x08) ---
send_frame(ser, [0x01, 0x05, 0x00, 0x08, 0xFF, 0x00], "Неверный регистр (0x08)")

# --- Тест 3: Испорченная CRC (запрос с корректной CRC заменён битой) ---
frame = [0x01, 0x05, 0x00, 0x00, 0xFF, 0x00]
full = bytes(frame) + crc16(bytes(frame))
# портим последний байт (изменяем старший байт CRC)
corrupted = full[:-1] + bytes([0x00])
print(f"\n--- Испорченная CRC ---")
print(f"TX: {corrupted.hex(' ').upper()}")
ser.write(corrupted)
time.sleep(0.3)
if ser.in_waiting:
    resp = ser.read(ser.in_waiting)
    print(f"RX: {resp.hex(' ').upper()}")
else:
    print("RX: (нет ответа)")

# --- Тест 4: Неизвестный код функции (0x10) ---
send_frame(ser, [0x01, 0x10, 0x00, 0x00, 0x00, 0x01], "Неизвестная функция (0x10)")

# --- Финальное чтение катушек для проверки, что состояние не изменилось ---
send_frame(ser, [0x01, 0x01, 0x00, 0x00, 0x00, 0x08], "Финальное чтение (должны быть 0xFF)")

ser.close()
print("\nТестирование завершено.")
