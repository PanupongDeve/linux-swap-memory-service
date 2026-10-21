# linux-swap-memory-service

บริการจัดการ Swap Memory อัตโนมัติบนระบบปฏิบัติการ Linux ทำงานร่วมกับ systemd เพื่อสร้างและเปิดใช้งาน swapfile ตามขนาดและตำแหน่งที่กำหนดได้อย่างยืดหยุ่น พร้อมระบบ Smart Reuse ที่ช่วยลดการเขียนข้อมูลซ้ำลงบนดิสก์

---

## ฟีเจอร์เด่น (Features)

- **Custom Swap Path**: กำหนดตำแหน่งไฟล์ swap ได้อย่างอิสระ เช่น ย้ายไปเก็บที่ดิสก์ลูกอื่น (`/mnt/data/swapfile`) หรือพาธที่ต้องการ
- **Configuration Precedence**: ปรับแต่งค่าผ่าน `/etc/swap-memory.conf` หรือส่งค่าผ่าน CLI flags โดยมี fallback เริ่มต้นเป็น `/swapfile` ขนาด 8GB
- **Smart Reuse**: ตรวจสอบขนาดไฟล์เดิมก่อนเสมอ หากมีอยู่แล้วและขนาดตรงกัน จะเปิดใช้งานต่อทันทีโดยไม่ format ซ้ำ ช่วยยืดอายุการใช้งาน SSD/NVMe
- **Isolated Swap Management**: จัดการและปิด swap เฉพาะไฟล์ที่กำหนดเท่านั้น ไม่ใช้ `swapoff -a` จึงไม่ส่งผลกระทบต่อ zram หรือ swap partition อื่นในระบบ
- **Clean Service Lifecycle**: ปิด swapfile อัตโนมัติเมื่อสั่งหยุด service (`systemctl stop`) และมีตัวเลือกคืนพื้นที่ดิสก์เมื่อถอนการติดตั้ง

---

## การติดตั้ง (Installation)

### 1. ติดตั้งแบบค่าเริ่มต้น (/swapfile ขนาด 8GB)
```bash
sudo ./install.sh
```

### 2. ติดตั้งพร้อมกำหนด Path และขนาดเอง
```bash
sudo ./install.sh --path /mnt/fast-disk/swapfile --size 16
```

---

## การตั้งค่า (Configuration)

เมื่อติดตั้งแล้ว ระบบจะสร้างไฟล์คอนฟิกไว้ที่ `/etc/swap-memory.conf` สามารถแก้ไขไฟล์นี้ได้โดยตรง:

```bash
# /etc/swap-memory.conf
SWAP_PATH="/swapfile"
SWAP_SIZE=8 # ขนาดหน่วยเป็น GB
```

หลังจากแก้ไขไฟล์คอนฟิก ให้รีสตาร์ต service:
```bash
sudo systemctl restart swap-memory.service
```

---

## การจัดการ Service ผ่าน Systemd

```bash
# ตรวจสอบสถานะการทำงาน
sudo systemctl status swap-memory.service

# เริ่มการทำงานของ service
sudo systemctl start swap-memory.service

# หยุดการทำงาน (จะทำ swapoff เฉพาะ swapfile นี้ให้อัตโนมัติ)
sudo systemctl stop swap-memory.service

# รีสตาร์ต service
sudo systemctl restart swap-memory.service
```

---

## การใช้งานผ่าน Command-line (Manual CLI)

สามารถเรียกใช้งานสคริปต์ `/usr/local/bin/swap-memory.sh` ได้โดยตรง:

```bash
# แสดงข้อความช่วยเหลือ
/usr/local/bin/swap-memory.sh --help

# สร้างหรือเปิดใช้งาน swapfile ตามคอนฟิก
sudo /usr/local/bin/swap-memory.sh

# ระบุ path และขนาดผ่าน flags (จะ override ค่าใน config ชั่วคราว)
sudo /usr/local/bin/swap-memory.sh -p /var/cache/custom-swap -s 4

# ระบุแบบ positional argument (รองรับรูปแบบเดิม)
sudo /usr/local/bin/swap-memory.sh 16 /mnt/data/swapfile

# ปิดการใช้งาน swapfile เฉพาะไฟล์ที่กำหนด
sudo /usr/local/bin/swap-memory.sh --stop
```

---

## การทดสอบระบบ (Running Tests)

โปรเจกต์นี้มีชุดทดสอบอัตโนมัติ (Bash Test Runner) ในตัว รันได้ทันทีโดยไม่ต้องติดตั้ง dependency เพิ่มเติม:

```bash
bash tests/test_runner.sh
```

---

## การถอนการติดตั้ง (Uninstallation)

```bash
# ถอนการติดตั้งแบบปกติ (ระบบจะถามยืนยันก่อนลบ swapfile เพื่อคืนพื้นที่ดิสก์)
sudo ./uninstall.sh

# ถอนการติดตั้งพร้อมลบ swapfile ทันทีโดยไม่ต้องถาม
sudo ./uninstall.sh -y --remove-swap
```
