-- ลบตารางเดิมถ้ามีอยู่ (ลบตารางลูกก่อนตารางแม่ หรือใช้ CASCADE)

DROP TABLE IF EXISTS receipt CASCADE;
DROP TABLE IF EXISTS visit_medicine CASCADE;
DROP TABLE IF EXISTS medicine CASCADE;
DROP TABLE IF EXISTS vet_specialty CASCADE;
DROP TABLE IF EXISTS visit CASCADE;
DROP TABLE IF EXISTS vet CASCADE;
DROP TABLE IF EXISTS animal CASCADE;
DROP TABLE IF EXISTS owner_phone CASCADE;
DROP TABLE IF EXISTS owner CASCADE;


-- 1. ตาราง owner (เจ้าของสัตว์)
-- หน้าที่: เก็บข้อมูลประวัติพื้นฐานของเจ้าของสัตว์เลี้ยง
-- ที่มา: เอนทิตี owner (กฎข้อ 1, 5)
CREATE TABLE owner (
    owner_id SERIAL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    address TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT pk_owner PRIMARY KEY (owner_id),
    CONSTRAINT ck_owner_first_name CHECK (length(trim(first_name)) > 0),
    CONSTRAINT ck_owner_last_name CHECK (length(trim(last_name)) > 0)
);

COMMENT ON TABLE owner IS 'ตารางเก็บข้อมูลเจ้าของสัตว์เลี้ยง (1 คน ลงทะเบียนไว้ได้แม้ยังไม่เคยพาสัตว์มารักษา)';
COMMENT ON COLUMN owner.owner_id IS 'รหัสเจ้าของสัตว์ (Primary Key)';
COMMENT ON COLUMN owner.first_name IS 'ชื่อจริงของเจ้าของ';
COMMENT ON COLUMN owner.last_name IS 'นามสกุลของเจ้าของ';
COMMENT ON COLUMN owner.address IS 'ที่อยู่ติดต่อ';


-- 2. ตาราง owner_phone (เบอร์โทรศัพท์ของเจ้าของ)
-- หน้าที่: เก็บเบอร์โทรศัพท์ของเจ้าของสัตว์ (รองรับพหุค่า: 1 เจ้าของมีหลายเบอร์)
-- ที่มา: แอททริบิวต์พหุค่า (Multivalued Attribute) ของ owner (กฎข้อ 2)
CREATE TABLE owner_phone (
    owner_id INT NOT NULL,
    phone_no VARCHAR(15) NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Constraints
    CONSTRAINT pk_owner_phone PRIMARY KEY (owner_id, phone_no),
    CONSTRAINT fk_owner_phone_owner FOREIGN KEY (owner_id)
        REFERENCES owner(owner_id)
        ON DELETE CASCADE, -- เหตุผล: ถ้าลบข้อมูลเจ้าของ เบอร์โทรศัพท์ของเจ้าของนั้นต้องถูกลบตามไปด้วย
    CONSTRAINT ck_owner_phone_format CHECK (length(trim(phone_no)) >= 9)
);

COMMENT ON TABLE owner_phone IS 'ตารางเก็บเบอร์โทรศัพท์ของเจ้าของ (รองรับกรณี 1 เจ้าของมีหลายเบอร์โทรศัพท์)';
COMMENT ON COLUMN owner_phone.owner_id IS 'รหัสเจ้าของ (Foreign Key อ้างอิง owner.owner_id)';
COMMENT ON COLUMN owner_phone.phone_no IS 'หมายเลขโทรศัพท์';
COMMENT ON COLUMN owner_phone.is_primary IS 'สถานะว่าเบอร์หลักหรือไม่ (TRUE = เบอร์หลัก)';


-- 3. ตาราง animal (สัตว์เลี้ยง)
-- หน้าที่: เก็บข้อมูลประวัติสัตว์เลี้ยง
-- ที่มา: เอนทิตี animal (กฎข้อ 3, 4) - สัมพันธ์ 1:M กับ owner
-- หมายเหตุ: ห้ามเก็บคอลัมน์ "อายุ" เนื่องจากเป็น Derived Attribute (คำนวณจาก birth_date)
CREATE TABLE animal (
    animal_id SERIAL,
    owner_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    species VARCHAR(50) NOT NULL,
    sex VARCHAR(10) NOT NULL,
    color VARCHAR(50),
    birth_date DATE,
    
    -- Constraints
    CONSTRAINT pk_animal PRIMARY KEY (animal_id),
    CONSTRAINT fk_animal_owner FOREIGN KEY (owner_id)
        REFERENCES owner(owner_id)
        ON DELETE CASCADE, -- เหตุผล: ถ้าลบข้อมูลเจ้าของ ข้อมูลสัตว์เลี้ยงของเจ้าของนั้นต้องถูกลบตามไปด้วย
    CONSTRAINT ck_animal_sex CHECK (sex IN ('M', 'F', 'U', 'ผู้', 'เมีย', 'ไม่ระบุ'))
);

COMMENT ON TABLE animal IS 'ตารางเก็บข้อมูลสัตว์เลี้ยง (1 ตัวมีเจ้าของได้ 1 คน ห้ามเก็บคอลัมน์อายุเพราะคำนวณจาก birth_date)';
COMMENT ON COLUMN animal.animal_id IS 'รหัสสัตว์เลี้ยง (Primary Key)';
COMMENT ON COLUMN animal.owner_id IS 'รหัสเจ้าของที่เป็นผู้เลี้ยง (Foreign Key อ้างอิง owner.owner_id)';
COMMENT ON COLUMN animal.name IS 'ชื่อสัตว์เลี้ยง';
COMMENT ON COLUMN animal.species IS 'สายพันธุ์/ชนิดสัตว์ (เช่น สุนัข, แมว)';
COMMENT ON COLUMN animal.sex IS 'เพศ (M/F/U)';


-- 4. ตาราง vet (สัตวแพทย์)
-- หน้าที่: เก็บข้อมูลประวัติและใบอนุญาตของสัตวแพทย์
-- ที่มา: เอนทิตี vet (กฎข้อ 8, 9)
CREATE TABLE vet (
    vet_id SERIAL,
    license_no VARCHAR(20) NOT NULL,
    name VARCHAR(150) NOT NULL,
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Constraints
    CONSTRAINT pk_vet PRIMARY KEY (vet_id),
    CONSTRAINT uq_vet_license_no UNIQUE (license_no), -- เลขใบอนุญาตห้ามซ้ำ
    CONSTRAINT ck_vet_license_no CHECK (length(trim(license_no)) > 0)
);

COMMENT ON TABLE vet IS 'ตารางเก็บข้อมูลสัตวแพทย์ในคลินิก (เลขใบอนุญาตห้ามซ้ำ)';
COMMENT ON COLUMN vet.vet_id IS 'รหัสสัตวแพทย์ (Primary Key)';
COMMENT ON COLUMN vet.license_no IS 'เลขที่ใบอนุญาตประกอบวิชาชีพ (UNIQUE)';
COMMENT ON COLUMN vet.name IS 'ชื่อ-นามสกุล สัตวแพทย์';


-- 5. ตาราง vet_specialty (ความเชี่ยวชาญของสัตวแพทย์)
-- หน้าที่: เก็บความเชี่ยวชาญเฉพาะทางของสัตวแพทย์
-- ที่มา: แอททริบิวต์พหุค่า/ความสัมพันธ์ M:N ของสัตวแพทย์ (กฎข้อ 10)
CREATE TABLE vet_specialty (
    vet_id INT NOT NULL,
    specialty VARCHAR(100) NOT NULL,
    
    -- Constraints
    CONSTRAINT pk_vet_specialty PRIMARY KEY (vet_id, specialty),
    CONSTRAINT fk_vet_specialty_vet FOREIGN KEY (vet_id)
        REFERENCES vet(vet_id)
        ON DELETE CASCADE -- เหตุผล: ถ้าลบสัตวแพทย์ ข้อมูลความเชี่ยวชาญของสัตวแพทย์คนนั้นต้องลบตาม
);

COMMENT ON TABLE vet_specialty IS 'ตารางเก็บความเชี่ยวชาญเฉพาะทางของสัตวแพทย์ (1 สัตวแพทย์มีความเชี่ยวชาญได้หลายด้าน)';
COMMENT ON COLUMN vet_specialty.vet_id IS 'รหัสสัตวแพทย์ (Foreign Key อ้างอิง vet.vet_id)';
COMMENT ON COLUMN vet_specialty.specialty IS 'สาขาความเชี่ยวชาญ (เช่น ศัลยกรรม, โรคผิวหนัง)';


-- 6. ตาราง visit (การเข้ารับบริการ / ประวัติการตรวจรักษา)
-- หน้าที่: เก็บประวัติการตรวจรักษาแต่ละครั้ง
-- ที่มา: เอนทิตีอ่อน (Weak Entity) ของ animal (กฎข้อ 6, 7)
--      ใช้ PK ผสม (animal_id, visit_no) เพื่อระบุการตรวจครั้งที่ n ของสัตว์ตัวนั้น
CREATE TABLE visit (
    animal_id INT NOT NULL,
    visit_no INT NOT NULL,
    visit_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    weight NUMERIC(5,2) NOT NULL,
    temperature NUMERIC(4,1) NOT NULL,
    symptom TEXT NOT NULL,
    diagnosis TEXT,
    vet_id INT NOT NULL,
    
    -- Constraints
    CONSTRAINT pk_visit PRIMARY KEY (animal_id, visit_no), -- PK ผสมสำหรับ Weak Entity
    CONSTRAINT fk_visit_animal FOREIGN KEY (animal_id)
        REFERENCES animal(animal_id)
        ON DELETE CASCADE, -- เหตุผล: ถ้าลบสัตว์เลี้ยง ประวัติการเข้ารับบริการทั้งหมดของสัตว์ตัวนั้นต้องถูกลบตาม (Weak Entity Dependency)
    CONSTRAINT fk_visit_vet FOREIGN KEY (vet_id)
        REFERENCES vet(vet_id)
        ON DELETE RESTRICT, -- เหตุผล: ห้ามลบสัตวแพทย์ที่มีประวัติเคยตรวจรักษาคนไข้ในระบบ
    CONSTRAINT ck_visit_visit_no CHECK (visit_no > 0),
    CONSTRAINT ck_visit_weight CHECK (weight > 0),
    CONSTRAINT ck_visit_temp CHECK (temperature >= 30.0 AND temperature <= 45.0)
);

COMMENT ON TABLE visit IS 'ตารางเก็บการเข้ารับบริการ (เอนทิตีอ่อน ใช้ PK ผสม animal_id + visit_no เพื่อบอกการเข้ารับบริการครั้งที่เท่าไร)';
COMMENT ON COLUMN visit.animal_id IS 'รหัสสัตว์เลี้ยง (Foreign Key และ Part of PK)';
COMMENT ON COLUMN visit.visit_no IS 'ลำดับครั้งที่เข้ารับบริการของสัตว์ตัวนั้น (Part of PK)';
COMMENT ON COLUMN visit.vet_id IS 'รหัสสัตวแพทย์ผู้ตรวจ (Foreign Key อ้างอิง vet.vet_id)';


-- หน้าที่: เก็บข้อมูลรายการยาและราคาปัจจุบัน
-- ที่มา: เอนทิตี medicine (กฎข้อ 12)
CREATE TABLE medicine (
    medicine_id SERIAL,
    name VARCHAR(150) NOT NULL,
    unit VARCHAR(30) NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    
    -- Constraints
    CONSTRAINT pk_medicine PRIMARY KEY (medicine_id),
    CONSTRAINT ck_medicine_unit_price CHECK (unit_price >= 0),
    CONSTRAINT ck_medicine_name CHECK (length(trim(name)) > 0)
);

COMMENT ON TABLE medicine IS 'ตารางเก็บข้อมูลยาและเวชภัณฑ์ (เก็บราคาขายปัจจุบัน)';
COMMENT ON COLUMN medicine.medicine_id IS 'รหัสยา (Primary Key)';
COMMENT ON COLUMN medicine.name IS 'ชื่อยา';
COMMENT ON COLUMN medicine.unit IS 'หน่วยนับ (เช่น เม็ด, ขวด, หลอด)';
COMMENT ON COLUMN medicine.unit_price IS 'ราคาต่อหน่วยปัจจุบัน';


-- 8. ตาราง visit_medicine (รายการจ่ายยาในการตรวจรักษา)
-- หน้าที่: ตารางเชื่อม M:N ระหว่าง visit กับ medicine
-- ที่มา: ความสัมพันธ์ M:N ระหว่างการเข้ารับบริการ และ ยา (กฎข้อ 11, 12)
CREATE TABLE visit_medicine (
    animal_id INT NOT NULL,
    visit_no INT NOT NULL,
    medicine_id INT NOT NULL,
    dosage VARCHAR(100) NOT NULL,
    days INT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT pk_visit_medicine PRIMARY KEY (animal_id, visit_no, medicine_id),
    CONSTRAINT fk_visit_medicine_visit FOREIGN KEY (animal_id, visit_no)
        REFERENCES visit(animal_id, visit_no)
        ON DELETE CASCADE, -- เหตุผล: ถ้าลบประวัติการตรวจรักษา รายการจ่ายยาในครั้งนั้นต้องถูกลบตาม
    CONSTRAINT fk_visit_medicine_medicine FOREIGN KEY (medicine_id)
        REFERENCES medicine(medicine_id)
        ON DELETE RESTRICT, -- เหตุผล: ห้ามลบรายการยาออกจากระบบ หากยายังมีประวัติถูกจ่ายให้คนไข้
    CONSTRAINT ck_visit_medicine_days CHECK (days > 0)
);

COMMENT ON TABLE visit_medicine IS 'ตารางเชื่อม M:N เก็บการจ่ายยาในการเข้ารับบริการแต่ละครั้ง พร้อมขนาดวิธีใช้และจำนวนวัน';
COMMENT ON COLUMN visit_medicine.animal_id IS 'รหัสสัตว์ (Part of Composite FK อ้างอิง visit)';
COMMENT ON COLUMN visit_medicine.visit_no IS 'ครั้งที่เข้ารับบริการ (Part of Composite FK อ้างอิง visit)';
COMMENT ON COLUMN visit_medicine.medicine_id IS 'รหัสยา (Foreign Key อ้างอิง medicine.medicine_id)';


-- 9. ตาราง receipt (ใบเสร็จรับเงิน)
-- หน้าที่: เก็บข้อมูลการชำระเงินของแต่ละการตรวจรักษา
-- ที่มา: ความสัมพันธ์ 1:1 กับ visit (กฎข้อ 13) - 1 visit ออกได้สูงสุด 1 ใบเสร็จ
CREATE TABLE receipt (
    receipt_id SERIAL,
    animal_id INT NOT NULL,
    visit_no INT NOT NULL,
    paid_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_amount NUMERIC(10,2) NOT NULL,
    
    -- Constraints
    CONSTRAINT pk_receipt PRIMARY KEY (receipt_id),
    CONSTRAINT uq_receipt_visit UNIQUE (animal_id, visit_no), -- บังคับความสัมพันธ์ 1:1 (1 visit ออกใบเสร็จซ้ำไม่ได้)
    CONSTRAINT fk_receipt_visit FOREIGN KEY (animal_id, visit_no)
        REFERENCES visit(animal_id, visit_no)
        ON DELETE RESTRICT, -- เหตุผล: ห้ามลบประวัติการตรวจรักษา หากออกใบเสร็จรับเงินไปแล้ว (ต้องเก็บเป็นหลักฐานทางบัญชี)
    CONSTRAINT ck_receipt_total_amount CHECK (total_amount >= 0)
);

COMMENT ON TABLE receipt IS 'ตารางเก็บใบเสร็จรับเงิน (ความสัมพันธ์ 1:1 กับ visit บังคับด้วย UNIQUE constraint บน FK)';
COMMENT ON COLUMN receipt.receipt_id IS 'เลขที่ใบเสร็จ (Primary Key)';
COMMENT ON COLUMN receipt.animal_id IS 'รหัสสัตว์ (Part of Composite FK & UQ อ้างอิง visit)';
COMMENT ON COLUMN receipt.visit_no IS 'ครั้งที่เข้ารับบริการ (Part of Composite FK & UQ อ้างอิง visit)';
COMMENT ON COLUMN receipt.total_amount IS 'ยอดเงินรวมที่ชำระ';