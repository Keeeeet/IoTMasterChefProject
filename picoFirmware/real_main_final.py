# ============================  main.py  =============================
# BLE „gril‑teploměr“ pro Raspberry Pi Pico W
#  – čte termočlánek přes driver MAX6675 (SPI1)
#  – každou sekundu posílá aktuální teplotu v °C (formát 0.00) pomocí Notify
# -------------------------------------------------------------------

import machine, time, bluetooth, struct
from micropython import const

# ---------------- Pin‑mapping pro MAX6675 přes SPI1 ----------------
SPI_SCK  = 10   # GP10 → SCK  
SPI_MISO = 12   # GP12 → SO
SPI_MOSI = 11   # GP11 není potřeba, ale vyžadováno SPI
PIN_CS   = 13   # GP13 → CS

# ---------------- Inicializace SPI1 a CS pinu -----------------------
spi = machine.SPI(
    1,
    baudrate = 5_000_000,
    polarity = 0,
    phase    = 0,
    sck  = machine.Pin(SPI_SCK),
    mosi = machine.Pin(SPI_MOSI),
    miso = machine.Pin(SPI_MISO),
)
cs = machine.Pin(PIN_CS, machine.Pin.OUT, value = 1)

def cti_teplotu():
    """Vrátí teplotu v °C (float) nebo None při chybě (obvod/odpor)."""
    cs(0)
    surova = spi.read(2)
    cs(1)

    hodnota = (surova[0] << 8) | surova[1]
    if hodnota & 0x04:
        return None
    return (hodnota >> 3) * 0.25

# -------------------- BLE část -------------------------------------
_IRQ_CENTRAL_CONNECT    = const(1)
_IRQ_CENTRAL_DISCONNECT = const(2)

UUID_ENV_SENSE = bluetooth.UUID(0x181A)
UUID_TEMP_CHAR = bluetooth.UUID(0x2A6E)

FLAG_READ   = const(0x0002)
FLAG_NOTIFY = const(0x0010)

def advertising_payload(limited_disc=False, br_edr=False, name=None,
                        services=None, appearance=0):
    payload = bytearray()
    def _append(typ, val):
        payload.extend(struct.pack("BB", len(val) + 1, typ) + val)

    _append(0x01, struct.pack("B", (0x02 if limited_disc else 0x04) + (0x18 if br_edr else 0x06)))
    if name:
        _append(0x09, name.encode())
    if services:
        for uuid in services:
            b = bytes(uuid)
            _append(0x03 if len(b) == 2 else 0x07, b)
    if appearance:
        _append(0x19, struct.pack("<h", appearance))
    return payload

class BLEGrilTeplomer:
    def __init__(self, ble, jmeno="PicoGrill"):
        self._ble = ble
        self._ble.active(True)
        self._ble.irq(self._irq)
        self._pripojeni = set()

        teplota_char = (UUID_TEMP_CHAR, FLAG_READ | FLAG_NOTIFY)
        teplota_svc  = (UUID_ENV_SENSE, (teplota_char,))
        ((self._handle_teplota,),) = self._ble.gatts_register_services((teplota_svc,))

        self._payload = advertising_payload(name=jmeno, services=[UUID_ENV_SENSE])
        self._reklamuj()
        self._smycka()

    def _irq(self, event, data):
        if event == _IRQ_CENTRAL_CONNECT:
            conn, _, _ = data
            self._pripojeni.add(conn)
            print("CENTRAL připojen (handle {})".format(conn))
        elif event == _IRQ_CENTRAL_DISCONNECT:
            conn, _, _ = data
            self._pripojeni.discard(conn)
            print("CENTRAL odpojen (handle {})".format(conn))
            self._reklamuj()

    def _reklamuj(self, interval_us=500_000):
        self._ble.gap_advertise(interval_us, adv_data=self._payload)
        print("Reklamuji se jako 'PicoGrill'…")

    def _smycka(self):
        while True:
            teplota = cti_teplotu()
            if teplota is None:
                print("Chyba čtení: otevřený termočlánek!")
                time.sleep(1)
                continue

            t_setiny = int(round(teplota * 100))
            data     = struct.pack("<h", t_setiny)

            self._ble.gatts_write(self._handle_teplota, data)
            for conn in self._pripojeni:
                self._ble.gatts_notify(conn, self._handle_teplota, data)

            print("Teplota aktuálně = {:.2f} °C (odesláno jako {})".format(teplota, t_setiny))
            time.sleep(1)


# ------------------------- Start programu -------------------------------------
ble = bluetooth.BLE()
BLEGrilTeplomer(ble)
# ============================================================================
