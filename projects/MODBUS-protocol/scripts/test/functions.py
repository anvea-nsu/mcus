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


def send_and_wait(ser, frame, timeout=0.5):
    ser.reset_input_buffer()
    crc = crc16(bytes(frame))
    full = bytes(frame) + crc
    print(f"TX: {full.hex(' ').upper()}")
    ser.write(full)
    
    start = time.time()
    resp = b''
    while (time.time() - start) < timeout:
        if ser.in_waiting:
            resp += ser.read(ser.in_waiting)
            if len(resp) >= 5:
                break
        time.sleep(0.01)
    if resp:
        print(f"RX: {resp.hex(' ').upper()}")
    else:
        print("RX: (нет ответа)")
    return resp


PORT = 'COM11'
ser = serial.Serial(PORT, baudrate=9600, timeout=0.5)

# --- ТЕСТ 1: Включить лампу 0 ---
print("\n>> ВКЛЮЧИТЬ лампу 0")
send_and_wait(ser, [0x01, 0x05, 0x00, 0x00, 0xFF, 0x00])
time.sleep(0.2)

# --- ТЕСТ 2: Чтение всех катушек ---
print("\n>> ЧТЕНИЕ всех катушек")
send_and_wait(ser, [0x01, 0x01, 0x00, 0x00, 0x00, 0x08])
time.sleep(0.2)

# --- ТЕСТ 3: Выключить лампу 0 ---
print("\n>> ВЫКЛЮЧИТЬ лампу 0")
send_and_wait(ser, [0x01, 0x05, 0x00, 0x00, 0x00, 0x00])
time.sleep(0.2)

# --- ТЕСТ 4: Включить все лампы ---
print("\n>> ВКЛЮЧИТЬ ВСЕ лампы")
send_and_wait(ser, [0x01, 0x0F, 0x00, 0x00, 0x00, 0x08, 0x01, 0xFF])
time.sleep(0.2)

# --- ТЕСТ 5: Финальное чтение ---
print("\n>> ЧТЕНИЕ после включения всех")
send_and_wait(ser, [0x01, 0x01, 0x00, 0x00, 0x00, 0x08])

ser.close()
print("\nГотово.")
