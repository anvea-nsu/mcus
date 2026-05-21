import serial
import struct
import time

PORT = 'COM11'
SLAVE_ID = 0x01


def crc16(data: bytes) -> bytes:
    crc = 0xFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if crc & 1 else crc >> 1
    return struct.pack('<H', crc)


def send_and_wait(ser, frame):
    ser.reset_input_buffer()
    crc = crc16(bytes(frame))
    full = bytes(frame) + crc
    print(f"TX: {full.hex(' ').upper()}")
    ser.write(full)
    time.sleep(0.05)
    resp = b''
    start = time.time()
    while (time.time() - start) < 0.5:
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


def read_coils(ser):
    frame = [SLAVE_ID, 0x01, 0x00, 0x00, 0x00, 0x08]
    resp = send_and_wait(ser, frame)
    if len(resp) >= 4 and resp[1] == 0x01:
        return resp[3]
    else:
        return None


def write_single_coil(ser, addr, state):
    val = 0xFF00 if state else 0x0000
    frame = [SLAVE_ID, 0x05, 0x00, addr, (val >> 8) & 0xFF, val & 0xFF]
    resp = send_and_wait(ser, frame)
    if len(resp) >= 6 and resp[1] == 0x05 and resp[2:4] == bytes(frame[2:4]):
        return True
    else:
        return False


def write_multiple_coils(ser, start, values):
    n = len(values)
    byte_cnt = (n + 7) // 8
    data = [0] * byte_cnt
    for i, v in enumerate(values):
        if v:
            data[i // 8] |= (1 << (i % 8))
    frame = [SLAVE_ID, 0x0F, 0x00, start, 0x00, n, byte_cnt] + data
    resp = send_and_wait(ser, frame)
    if len(resp) >= 6 and resp[1] == 0x0F:
        return True
    else:
        return False



try:
    ser = serial.Serial(PORT, baudrate=9600, timeout=0.5)
    print(f"Порт {PORT} открыт. Управление лампами (Slave ID={SLAVE_ID})")
except Exception as e:
    print(f"Ошибка открытия порта: {e}")
    exit()

print("Доступные команды:")
print("  on <n>           - включить одну лампу")
print("  off <n>          - выключить одну лампу")
print("  on <n1> <n2> ... - включить несколько ламп")
print("  off <n1> <n2> ...- выключить несколько ламп")
print("  all on            - включить все")
print("  all off           - выключить все")
print("  status            - показать состояние всех ламп")
print("  exit              - выход")
print("-" * 40)

while True:
    try:
        cmd = input("> ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        break
    if not cmd:
        continue

    parts = cmd.split()
    if parts[0] == 'exit':
        break

    elif parts[0] == 'status':
        state = read_coils(ser)
        if state is not None:
            bits = [(state >> i) & 1 for i in range(8)]
            print("Состояние ламп:")
            for i, b in enumerate(bits):
                print(f"  Лампа {i}: {'🟢 ВКЛ' if b else '⚫ ВЫКЛ'}")
            print(f"  HEX: 0x{state:02X}  BIN: {state:08b}")
        else:
            print("Ошибка чтения катушек.")

    elif parts[0] in ('on', 'off'):
        if len(parts) == 2 and parts[1] == 'all':
            state = (parts[0] == 'on')
            if write_multiple_coils(ser, 0, [state]*8):
                print(f"Все лампы {'включены' if state else 'выключены'}.")
            else:
                print("Ошибка записи.")

        # Одна лампа → Write Single Coil (0x05)
        elif len(parts) == 2:
            try:
                n = int(parts[1])
            except ValueError:
                print("Номер лампы должен быть числом 0-7.")
                continue
            if n < 0 or n > 7:
                print("Номер лампы должен быть от 0 до 7.")
                continue
            state = (parts[0] == 'on')
            if write_single_coil(ser, n, state):
                print(f"Лампа {n} {'включена' if state else 'выключена'}.")
            else:
                print("Ошибка записи.")

        # Несколько ламп → Write Multiple Coils (0x0F)
        elif len(parts) > 2:
            try:
                lamp_nums = [int(x) for x in parts[1:]]
            except ValueError:
                print("Номера ламп должны быть числами 0-7.")
                continue
            if any(n < 0 or n > 7 for n in lamp_nums):
                print("Номера ламп должны быть от 0 до 7.")
                continue

            current_state = read_coils(ser)
            if current_state is None:
                print("Не удалось прочитать текущее состояние ламп.")
                continue

            states = [(current_state >> i) & 1 == 1 for i in range(8)]
            for n in lamp_nums:
                states[n] = (parts[0] == 'on')

            if write_multiple_coils(ser, 0, states):
                action = "включены" if parts[0] == 'on' else "выключены"
                nums_str = ', '.join(str(n) for n in lamp_nums)
                print(f"Лампы {nums_str} {action}.")
            else:
                print("Ошибка записи.")
        else:
            print("Неверная команда.")
    else:
        print("Неизвестная команда. Примеры: on 0, off 3, all on, status, exit")

ser.close()
print("Порт закрыт.")
